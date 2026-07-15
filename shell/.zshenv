# 1Password SSH agent
export SSH_AUTH_SOCK="$HOME/.1password/agent.sock"
export GOENV_ROOT="$HOME/.goenv"
export GOBIN="$GOPATH/bin"
export PATH="$GOBIN:$GOENV_ROOT/bin:$PATH"

# Claude Code via AWS Bedrock
export CLAUDE_CODE_USE_BEDROCK=1
export AWS_REGION=ap-northeast-1
export ANTHROPIC_MODEL='global.anthropic.claude-fable-5'
export ANTHROPIC_DEFAULT_HAIKU_MODEL='jp.anthropic.claude-haiku-4-5-20251001-v1:0'

# シークレット類はGit管理外の ~/.zshenv.local に置く (AWS_BEARER_TOKEN_BEDROCK など)
[ -f ~/.zshenv.local ] && source ~/.zshenv.local
