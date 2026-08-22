// CI checks for the zezav-bolt Puppet Bolt project
//
// Every function marked +check runs in a single shared container (built once
// per session in New): the gem layers depend only on Gemfile, Gemfile.lock,
// and .bundle/config, so the image is rebuilt only when dependencies change.

package main

import (
	"context"
	"dagger/zazav-bolt/internal/dagger"
	"fmt"
)

type ZazavBolt struct {
	Source *dagger.Directory
	Env    *dagger.Container
}

func New(
	// The source directory to be used in the module's functions
	// +defaultPath="."
	// +ignore=[".git", ".modules", ".resource_types", ".bundle/gems", ".bundle/bin", "logs", "bolt-debug.log", ".plan_cache.json", ".task_cache.json", ".rerun.json"]
	source *dagger.Directory,
) *ZazavBolt {
	return &ZazavBolt{
		Source: source,
		Env:    getContainer(source),
	}
}

// The +check functions below mirror the mise leaf tasks 1:1 (mise
// `check::foo` → dagger `check-foo`, `lint::foo` → `lint-foo`) so CI results
// are visible per task. Keep both sides in sync when adding a task.

// Mirrors mise check::puppetfile — validate Puppetfile module pins with r10k
// +check
func (m *ZazavBolt) CheckPuppetfile(ctx context.Context) error {
	_, err := m.Env.
		WithExec([]string{"bundle", "exec", "r10k", "puppetfile", "check"}).
		Sync(ctx)
	return err
}

// Mirrors mise check::puppet — puppet parser validate on manifests and site
// +check
func (m *ZazavBolt) CheckPuppet(ctx context.Context) error {
	_, err := m.Env.
		WithExec([]string{"sh", "-c", "bundle exec puppet parser validate $(find manifests site -type f -name '*.pp')"}).
		Sync(ctx)
	return err
}

// Mirrors mise check::plans — puppet parser validate (plan language) on plans/
// +check
func (m *ZazavBolt) CheckPlans(ctx context.Context) error {
	_, err := m.Env.
		WithExec([]string{"bundle", "exec", "puppet", "parser", "validate", "--tasks", "plans"}).
		Sync(ctx)
	return err
}

// Mirrors mise check::epp — validate all .epp templates under site/
// +check
func (m *ZazavBolt) CheckEpp(ctx context.Context) error {
	_, err := m.Env.
		WithExec([]string{"sh", "-c", "bundle exec puppet epp validate $(find site -type f -name '*.epp')"}).
		Sync(ctx)
	return err
}

// Mirrors mise check::erb — validate all .erb templates under site/
// +check
func (m *ZazavBolt) CheckErb(ctx context.Context) error {
	_, err := m.Env.
		WithExec([]string{"sh", "-c", `find site -type f -name '*.erb' -exec sh -c 'erb -P -x -T - "$1" | ruby -c' _ {} \;`}).
		Sync(ctx)
	return err
}

// Mirrors mise check::hiera — parse-check all data/ YAML
// +check
func (m *ZazavBolt) CheckHiera(ctx context.Context) error {
	_, err := m.Env.
		WithExec([]string{"sh", "-c", `ruby -ryaml -e 'ARGV.each { |f| YAML.safe_load(File.read(f), aliases: true) }' $(find data -type f \( -name '*.yaml' -o -name '*.yml' \))`}).
		Sync(ctx)
	return err
}

// Mirrors mise lint::puppet — puppet-lint (fail on warnings) on manifests and site
// +check
func (m *ZazavBolt) LintPuppet(ctx context.Context) error {
	_, err := m.Env.
		WithExec([]string{"sh", "-c", "bundle exec puppet-lint --with-filename --fail-on-warnings --with-context $(find manifests site -type f -name '*.pp')"}).
		Sync(ctx)
	return err
}

// Mirrors mise lint::yaml — yamllint on data/
// +check
func (m *ZazavBolt) LintYaml(ctx context.Context) error {
	_, err := m.Env.
		WithExec([]string{"yamllint", "data/"}).
		Sync(ctx)
	return err
}

// Mirrors mise lint::prettier — check YAML/JSON/MD formatting
// +check
func (m *ZazavBolt) LintPrettier(ctx context.Context) error {
	_, err := m.Env.
		WithExec([]string{"prettier", "-c", "."}).
		Sync(ctx)
	return err
}

// Mirrors mise lint::editorconfig — check files against .editorconfig
// +check
func (m *ZazavBolt) LintEditorconfig(ctx context.Context) error {
	_, err := m.Env.
		WithExec([]string{"editorconfig-checker"}).
		Sync(ctx)
	return err
}

// Runs rspec-puppet unit tests on the source code.
// Not a +check on purpose: installing the Puppet modules makes it too slow
// for the check fan-out — CI runs it as a separate `dagger call test` job.
func (m *ZazavBolt) Test(ctx context.Context) error {
	_, err := m.Env.
		// .modules/ is gitignored, so the CI checkout doesn't have it —
		// install the pinned Puppet modules before compiling catalogs.
		WithExec([]string{"bundle", "exec", "bolt", "module", "install", "--force"}).
		WithExec([]string{"bundle", "exec", "rspec"}).
		Sync(ctx)
	return err
}

// ----- Helper funtions -----
func getContainer(source *dagger.Directory) *dagger.Container {
	const (
		ecVersion = "3.6.1"
		platform  = "linux"
		arch      = "amd64"
	)
	ecUrl := fmt.Sprintf("https://github.com/editorconfig-checker/editorconfig-checker/releases/download/v%s/editorconfig-checker_%s_%s_%s.apk", ecVersion, ecVersion, platform, arch)
	ecApk := dag.HTTP(ecUrl)

	base := dag.Container().
		From("alpine:3.19").
		WithExec([]string{"apk", "add", "--no-cache",
			"ruby", "ruby-bundler", "ruby-full", "ruby-dev", "build-base", "libffi-dev", "zlib-dev", "yaml-dev", "nodejs", "npm", "wget", "yamllint",
		}).
		WithExec([]string{"npm", "install", "-g", "prettier@3.8"})

	deps := base.
		WithFile("/tmp/editorconfig-checker.apk", ecApk).
		WithExec([]string{"apk", "add", "--allow-untrusted", "--no-cache", "/tmp/editorconfig-checker.apk"}).
		WithExec([]string{"rm", "/tmp/editorconfig-checker.apk"}).
		WithFile("/app/Gemfile", source.File("Gemfile")).
		WithFile("/app/Gemfile.lock", source.File("Gemfile.lock")).
		// Only the bundler config — never the vendored gems/binstubs — so this
		// layer's cache key is stable across source changes.
		WithFile("/app/.bundle/config", source.File(".bundle/config")).
		WithWorkdir("/app").
		WithExec([]string{"bundle", "install"})

	return deps.
		WithDirectory("/app", source)
}
