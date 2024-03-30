# AshPaperTrail

Creates and manage a version tracking resource for a given resource.

The version resource's changes attribute will be a dumped map of the original resource. You can configure it to be a complete snapshot or just the changes.

## Setup

First, add `ash_paper_trail` dependency

```
def deps do
  [
    ...
    {:ash_paper_trail, "~> 0.1.1"}
  ]
end
```

The follow the [getting started guide](documentation/tutorials/get-started-with-paper-trail.md)
