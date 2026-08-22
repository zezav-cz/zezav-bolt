# Testing

Unit tests are [rspec-puppet](https://github.com/puppetlabs/rspec-puppet) catalog
specs: each spec compiles a class or defined type into a catalog and asserts on
the resources it contains. Nothing is applied anywhere — tests run entirely
offline against the modules in `site/` and `.modules/`.

## Running tests

```bash
mise run test                # full suite, serial, documentation output
mise run test:parallel       # full suite, one rspec process per CPU core, dot output
```

`mise run ci` runs the parallel suite alongside `lint` (which includes the
parse-validity `check` tasks). In CI proper, GitHub Actions runs the Dagger
checks (`.dagger/main.go`) plus a separate `dagger call test` job, which
installs the pinned Puppet modules and runs the same rspec suite inside a
container (kept out of the check fan-out because it's slow).

### Selecting specific tests

Extra arguments to `mise run test` pass straight through to rspec:

```bash
# one spec file
mise run test -- spec/classes/profile/sysctl_spec.rb

# one directory
mise run test -- spec/classes/web

# a single example, by line number
mise run test -- spec/classes/profile/sysctl_spec.rb:12

# by example name (substring match)
mise run test -- -e 'reloads sysctl'

# only the Debian 13 contexts
mise run test -- -e debian-13
```

`bundle exec rspec …` works identically if you prefer to skip mise.

### Parallel vs. serial

`test:parallel` uses [parallel_tests](https://github.com/grosser/parallel_tests)
to split the spec _files_ across CPU cores (`parallel_rspec spec/`). Each
worker is a separate rspec process with its own Puppet setup, so results are
identical to a serial run — only faster (roughly 3–4× on a typical laptop).
Workers print dots (`--format progress`) because interleaved documentation
output from several processes is unreadable; failures are still reported in
full at the end.

Use the serial `mise run test` when you want:

- readable, ordered documentation output (one line per example)
- to pass rspec CLI options (`-e`, file:line, `--fail-fast`) — the passthrough
  is only wired up on the serial task
- simpler debugging (a single process to inspect, no worker env vars)

Use `test:parallel` for full-suite runs where you only care about pass/fail.

## Layout

```
spec/
├── spec_helper.rb           # module path, hiera config, OS matrix helper
├── classes/                 # one spec per class, mirroring site/<module>/manifests/
│   ├── profile/…
│   ├── web/…
│   ├── podman_quadlet/…
│   ├── monitoring/…
│   ├── general/…
│   └── zezav_bolt/          # node classification (manifests/nodes.pp)
├── defines/                 # defined types (podman_quadlet::container, …)
└── fixtures/
    ├── hiera/               # test-only hiera data — specs never read data/
    └── modules/zezav_bolt/  # symlink exposing manifests/ as the zezav_bolt module
```

## The OS matrix — Debian 12 and 13 only

`spec_helper.rb` defines `on_debian_os`, a wrapper around rspec-puppet-facts
that restricts the fact sets to Debian 12 (bookworm) and Debian 13 (trixie) —
the only releases in the fleet. Every spec iterates over it:

```ruby
describe 'profile::timesync' do
  on_debian_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile.with_all_deps }
    end
  end
end
```

Fact sets come from [facterdb](https://github.com/voxpupuli/facterdb) and are
real captured Facter output. Note the key convention when overriding facts:
top-level keys are **symbols**, nested keys are **strings**:

```ruby
let(:facts) do
  os_facts.merge(
    networking: os_facts[:networking].merge('hostname' => 'z01'),
  )
end
```

## Hiera in specs

Specs resolve hiera through `spec/fixtures/hiera/hiera.yaml`, which reads only
`spec/fixtures/hiera/data/common.yaml`. This keeps tests decoupled from
production `data/` (and its secrets). If a class gains a new mandatory
`lookup()`/class param that production supplies via hiera, add a test value to
the fixture `common.yaml` — prefer `let(:params)` in the spec when the value is
only needed by one class.

Module-level hiera (e.g. `site/monitoring/data/hashsums.yaml`) is picked up
automatically; no fixture needed.

## Conventions and pitfalls

- A new class, defined type, or plan isn't done until it has a spec. Every
  spec asserts at least `is_expected.to compile.with_all_deps`.
- Classes that read across module boundaries need a `pre_condition`, mirroring
  the production include order (e.g. `include profile::server_firewall` for
  `web`, `include nginx` for the vhost classes, `include podman_quadlet` for
  the container classes).
- Deep hash parameters (`quadlets::quadlet` entries) are matched **exactly** by
  `with_container_entry(...)` — rspec matchers like `include` don't nest inside
  it. To assert on part of the hash, read the parameter off the catalog:

  ```ruby
  entry = catalogue.resource('Quadlets::Quadlet', 'mc.container')[:container_entry]
  expect(entry['PodmanArgs']).to eq(['--publish 127.0.0.1:25565:25565'])
  ```

- There is **no Rakefile** — `bundle exec rake spec` will fail; use
  `mise run test`.
- Don't run `rspec-puppet setup` (it fails with _"Unable to find a
  metadata.json file"_): it scaffolds standalone modules and doesn't apply to
  this Bolt project layout. The equivalent wiring lives in `spec/spec_helper.rb`.
- `profile::fail2ban` has no spec: the `fail2ban` module it includes is not yet
  pinned in `bolt-project.yaml`, so its catalog cannot compile (see TODO.md).
- Bolt plans (`plans/install.pp`) are not covered yet; the plan is to use
  `bolt_spec/plans` for those (see TODO.md).
