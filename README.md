# Asana CLI tree

This is a ruby script that prints out a command line tree representation of all tasks in an Asana workspace.

## What for?

I currently use Asana to keep track of a lot of personal tasks and projects. Since I don't assign them to myself, there's no easy way to see them all in one place. Especially since the Asana UI doesn't have great support for showing tasks + subtasks together.

## Installation

Copy `config-sample.yml` to `~/.asana-cli-tree.yml` and customize the values appropriately.

TODO: Explain config values.

## Usage

```bash
$ ruby view-tasks.rb --load
# first usage
$ ruby view-tasks.rb
# shows cached data
```

## Sample output

It actually comes out with helpful shell coloring, but I can't embed that.

Here's a snippet of one project (a Probate task list I'm working on):

```bash
============================== PROBATE ==============================

Physical & Digital Objects:
UK personal effects
  art inventory
  distribution
  reimburse for shipped things
scan letters & memorabilia
  scan legal docs
distribute digital files
  buy flash drives
  distribute files

House:
PAY PROPERTY TAXES
  summer 2017

Estate Admin:
distribute cash
  set for house fund
2016 estate income taxes
  federal taxes
  state taxes
final probate doc
close estate acct

```

## License

Todo
