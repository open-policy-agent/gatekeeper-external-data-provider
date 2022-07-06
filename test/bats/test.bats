#!/usr/bin/env bats

load helpers

WAIT_TIME=120
SLEEP_TIME=1
GATEKEEPER_NAMESPACE=${GATEKEEPER_NAMESPACE:-gatekeeper-system}

teardown_file() {
  kubectl delete -f validation/
  kubectl delete -f mutation/
}

@test "gatekeeper-controller-manager is running" {
  wait_for_process ${WAIT_TIME} ${SLEEP_TIME} "kubectl -n ${GATEKEEPER_NAMESPACE} wait --for=condition=Ready --timeout=60s pod -l control-plane=controller-manager"
}

@test "gatekeeper-audit is running" {
  wait_for_process ${WAIT_TIME} ${SLEEP_TIME} "kubectl -n ${GATEKEEPER_NAMESPACE} wait --for=condition=Ready --timeout=60s pod -l control-plane=audit-controller"
}

@test "external-data-provider is running" {
  wait_for_process ${WAIT_TIME} ${SLEEP_TIME} "kubectl -n ${GATEKEEPER_NAMESPACE} wait --for=condition=Ready --timeout=60s pod -l run=external-data-provider"
}

@test "external data validation" {
  run kubectl apply -f validation/external-data-provider-constraint-template.yaml
  assert_success
  wait_for_process ${WAIT_TIME} ${SLEEP_TIME} "constraint_enforced constrainttemplate k8sexternaldatavalidation"

  run kubectl apply -f validation/external-data-provider-constraint.yaml
  assert_success
  wait_for_process ${WAIT_TIME} ${SLEEP_TIME} "constraint_enforced k8sexternaldatavalidation deny-images-with-invalid-suffix"

  run kubectl run nginx --image=error_nginx --dry-run=server
  # should deny pod admission if the image name has an "error_" prefix
  assert_failure
  assert_match 'error_nginx' "${output}"
  assert_match 'error_nginx_invalid' "${output}"
}

@test "external data mutation" {
  run kubectl apply -f mutation/external-data-provider-mutation.yaml
  assert_success
  wait_for_process ${WAIT_TIME} ${SLEEP_TIME} "mutator_enforced Assign append-valid-suffix-to-image"

  run kubectl run nginx --image=nginx --dry-run=server --output json
  assert_success
  # should mutate the image field by appending "_valid" suffix
  assert_match "nginx_valid" "$(jq -r '.spec.containers[0].image' <<< ${output})"
}
