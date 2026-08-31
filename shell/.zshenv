# 1Password SSH agent
export SSH_AUTH_SOCK="$HOME/.1password/agent.sock"
export GOENV_ROOT="$HOME/.goenv"
export GOBIN="$GOPATH/bin"
export PATH="$GOBIN:$GOENV_ROOT/bin:$PATH"

# シークレット類はGit管理外の ~/.zshenv.local に置く
[ -f ~/.zshenv.local ] && source ~/.zshenv.local
