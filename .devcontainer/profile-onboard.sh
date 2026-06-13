# Launch onboarding once per login session on first interactive shell.
if [[ -n "${PS1:-}" ]] \
  && [[ -z "${SWIFT_DEV_ONBOARDING_SESSION:-}" ]] \
  && [[ "${SKIP_ONBOARDING:-}" != "1" ]] \
  && [[ -x /usr/local/bin/onboard ]]; then
  export SWIFT_DEV_ONBOARDING_SESSION=1
  /usr/local/bin/onboard --if-needed || true
fi
