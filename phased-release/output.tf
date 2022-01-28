/* output "modified_rules_version" {
  value = resource.akamai_cloudlets_policy.phased_release.id
} */

output "active_version" {
  value = resource.akamai_cloudlets_policy_activation.pr_staging_latest.version
}
