# Open repo

Open the current directory repo in your browser straight from the terminal.

## Installation

```sh
git clone https://github.com/alphatechnolog/open-repo.git && cd open-repo
sudo zig build -p /usr -Doptimize=ReleaseSafe install
```

Also make sure you've installed these with your distribution pkgs managers

- git
- xdg-utils (supplies the xdg-open command).

## Usage

For now the program kinda fails when our cwd isn't a git repository, but the idea is that you cd into a git repository folder and then use

```sh
open-repo
```

This will open a browser with the opened repository.

> [!NOTE]
> This program also works with ssh based git urls, take a look at the output of `git remote get-url <origin>`

## Todo

- [ ] Be able to specify the remote to open, for now, default will be `origin`, which is usually the right choice.