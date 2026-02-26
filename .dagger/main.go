// A generated module for ZazavBolt functions
//
// This module has been generated via dagger init and serves as a reference to
// basic module structure as you get started with Dagger.
//
// Two functions have been pre-created. You can modify, delete, or add to them,
// as needed. They demonstrate usage of arguments and return types using simple
// echo and grep commands. The functions can be called from the dagger CLI or
// from one of the SDKs.
//
// The first line in this comment block is a short description line and the
// rest is a long description with more detail on the module's purpose or usage,
// if appropriate. All modules should have a short description.

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
	source *dagger.Directory,
) *ZazavBolt {
	return &ZazavBolt{
		Source: source,
		Env:    getContainer(source),
	}
}

// Runs puppet-lint on the source code
// +check
func (m *ZazavBolt) PuppetLint(ctx context.Context) error {
	_, err := m.Env.
		WithExec([]string{"bundle", "exec", "puppet-lint", "."}).
		Sync(ctx)
	return err
}

// Runs editorconfig-checker on the source code
// +check
func (m *ZazavBolt) EditorConfigChecker(ctx context.Context) error {
	_, err := m.Env.
		WithExec([]string{"editorconfig-checker"}).
		Sync(ctx)
	return err
}

// Runs prettier on the source code
// +check
func (m *ZazavBolt) Prettier(ctx context.Context) error {
	_, err := m.Env.
		WithExec([]string{"prettier", "-c", "."}).
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
			"ruby", "ruby-bundler", "ruby-full", "ruby-dev", "build-base", "libffi-dev", "zlib-dev", "yaml-dev", "nodejs", "npm", "wget",
		}).
		WithExec([]string{"npm", "install", "-g", "prettier@3.8"})

	deps:= base.
		WithFile("/tmp/editorconfig-checker.apk", ecApk).
		WithExec([]string{"apk", "add", "--allow-untrusted", "--no-cache", "/tmp/editorconfig-checker.apk"}).
		WithExec([]string{"rm", "/tmp/editorconfig-checker.apk"}).
		WithFile("/app/Gemfile", source.File("Gemfile")).
		WithFile("/app/Gemfile.lock", source.File("Gemfile.lock")).
		WithDirectory("/app/.bundle", source.Directory(".bundle")).
		WithWorkdir("/app").
		WithExec([]string{"bundle", "install"})

	return deps.
		WithDirectory("/app", source)
}
