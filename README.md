# Rapid generation of BOSH releases

Generators for creating, updating, and sharing BOSH releases.

## Install

`bosh-gen` is distributed as a RubyGem:

```plain
gem install bosh-gen
```

## Requirements

When you run `bosh-gen new` to create a new BOSH release it will attempt to create an AWS S3 bucket to store your blobs, vendored packages (language packs), and final releases. You will need a AWS account and appropriate AWS keys.

If you'd like, contact [Dr Nic](mailto:drnic@starkandwayne.com) for credentials to the CF Community AWS account.

## Creating a new BOSH release

The `bosh-gen new [name]` subcommand is where you get started. It will create a `name-boshrelease` folder in your local directory filled with everything to make a working BOSH release (that doesn't do anything):

```plain
bosh-gen new my-system
```

You will be prompted for your AWS credentials. If you have a `~/.fog` file, then it will allow you to pick on of those credential pairs. Yes, I should add support for `~/.aws/credentials` too. Yes, I should add support for GCP bucket stores too.

A new AWS S3 bucket will be created for you called `my-system-boshrelease`, and am S3 policy will be attached to make its contents publicly readable to your BOSH release users.

An initial BOSH deployment manifest will be provided that "just works". Try it out:

```plain
export BOSH_DEPLOYMENT=my-system
bosh deploy manifests/my-system.yml
```

This will create/package your BOSH release, upload it to your BOSH environment, and deploy an VM that does nothing. 

```plain
Task 4525 | 10:56:28 | Creating missing vms: mything/27f862a1-a51b-468d-b3c5-35750eac483a (0) (00:00:15)
```

You're up and running and can now iterate towards your final BOSH release.

Your initial BOSH release scaffold includes:

* An initial `README.md` for your users (please keep this updated with any instructions specific to your release and deployment manifests)
* 0 packages
* 1 job called `my-system` with an empty `monit` file
* 1 deployment manifest `manifests/my-system.yml` with `version: create` set so that every `bosh deploy` will always create/upload a new version of your release during initial development
* Some sample operator files that you or your users might use to deploy your BOSH release

### BPM

It is assumed that you will be using BOSH Process Manager (BPM) to describe your BOSH jobs, so it has already been included in your deployment manifest. You will have seen it compiled during your initial `bosh deploy` above:

```plain
Task 4525 | 10:55:33 | Compiling packages: bpm-runc/c0b41921c5063378870a7c8867c6dc1aa84e7d85
Task 4525 | 10:55:33 | Compiling packages: golang/65c792cb5cb0ba6526742b1a36e57d1b195fe8be
Task 4525 | 10:55:51 | Compiling packages: bpm-runc/c0b41921c5063378870a7c8867c6dc1aa84e7d85 (00:00:18)
Task 4525 | 10:56:16 | Compiling packages: golang/65c792cb5cb0ba6526742b1a36e57d1b195fe8be (00:00:43)
Task 4525 | 10:56:16 | Compiling packages: bpm/b5e1678ac76dd5653bfa65cb237c0282e083894a (00:00:11)
```

You can see it included within your manifest's `addons:` section:

```yaml
addons:
- name: bpm
  jobs: [{name: bpm, release: bpm}]
```

It is possible that BPM will become a first-class built-in feature of BOSH environments in the future, and then this `addons` section can be removed. For now, it is an addon for your deployment manifest. BPM will make your life as a BOSH release developer easier.

## Jobs and packages

When you're finished and have a working BOSH release, base deployment manifest (`manifests/my-system.yml`), and optional operator files (`manifests/operators`) your BOSH release will include one or more jobs, and one or more packages.

I personally tend to iterate by writing packages first, getting them to compile, and then writing jobs to configure and run the packaged software. So I'll suggest this approach to you.

## Writing a package

Helpful commands from `bosh-gen`:

* `bosh-gen package name` - create a `packages/name` folder with initial `spec` and `packaging` file
* `bosh-gen extract-pkg /path/to/release/packages/name` - import a package folder from other BOSH release on your local machine, and its blobs and src files.

The `bosh` CLI also has helpful commands to create/borrow packages:

* `bosh generate-package name` - create a `packages/name` folder with initial `spec` and `packaging` file
* `bosh vendor-package name /path/to/release` - import the final release of a package from other BOSH release ([see blog post](https://starkandwayne.com/blog/build-bosh-releases-faster-with-language-packs/)), not the source of the package and its blobs.

Let's create a `redis` package a few different ways to see the differences.

## Vendoring a package from another release

If there is another BOSH release that has a package that you want, consider vendoring it.

There is already a [redis-boshrelease](https://github.com/cloudfoundry-community/redis-boshrelease) with a `redis-4` package.

```plain
mkdir ~/workspace
git clone https://github.com/cloudfoundry-community/redis-boshrelease ~/workspace/redis-boshrelease

bosh vendor-package redis-4 ~/workspace/redis-boshrelease
```

This command will download the final release version of the `redis-4` package from the `redis-boshrelease` S3 bucket, and then upload it to your own BOSH release's S3 bucket:

```plain
-- Finished downloading 'redis-4/5c3e41...'
Adding package 'redis-4/5c3e41...'...
-- Started uploading 'redis-4/5c3e41...'
2018/04/18 08:18:25 Successfully uploaded file to https://s3.amazonaws.com/my-system-boshrelease/108682c9...
-- Finished uploading 'redis-4/5c3e41...'
Added package 'redis-4/5c3e41...'
```

It will then reference this uploaded blob with the `packages/redis-4/spec.lock` file in your BOSH release project folder.

To include the `redis-4` package in your deployment, it needs to be referenced by a job.

Change `jobs/my-system/spec` YAML file's `packages` section to reference your `redis-4` package:

```yaml
---
name: my-system
packages: [redis-4]
templates:
  ignoreme: ignoreme
properties: {}
```

Now re-deploy to see your `redis-4` package compiled:

```plain
bosh deploy manifests/my-system.yml
```

The output will include:

```plain
Task 4550 | 12:24:46 | Compiling packages: redis-4/5c3e41... (00:00:57)
```

We can `bosh ssh` into our running `my-system` instance to confirm that `redis-server` and `redis-cli` binaries are available to us:

```plain
bosh ssh
```

Inside the VM, list the binaries that have been installed with our package:

```plain
$ ls /var/vcap/packages/redis-4/bin
redis-benchmark  redis-check-aof  redis-check-rdb  redis-cli  redis-sentinel  redis-server
```

A note in advance for writing our BOSH job, these binaries are not in the normal `$PATH` location. They are in `/var/vcap/packages/redis-4` folder.