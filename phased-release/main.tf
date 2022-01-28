# our phased release cloudlet test
terraform {
  required_providers {
    akamai = {
      source  = "akamai/akamai"
      version = "1.10.0"
    }
  }
}

# for cloud usage these vars have been defined in terraform cloud as a set
# Configure the Akamai Provider to use betajam credentials
provider "akamai" {
  edgerc         = "~/.edgerc"
  config_section = "betajam"
}

# just use group_name to lookup our contract_id and group_id
# this will simplify our variables file as this contains contract and group id
# use "akamai property groups list" to find all your groups 
data "akamai_contract" "contract" {
  group_name = var.group_name
}

# an example on how to create the rules to be used in the policy via a data source
# use the .json to return json formatted rules from this data source.
data "akamai_cloudlets_phased_release_match_rule" "to_deta" {
  match_rules {
    name = "to_deta"
    forward_settings {
      origin_id = "deta"
      percent   = 100
    }
    matches {
      case_sensitive = false
      match_operator = "contains"
      match_type     = "path"
      match_value    = var.to_deta_match_value
      negate         = false
    }
  }
}

# this phased release policy has been pre-created in Akamai Control Center.
# the property we are going to use has already setup some rules using the phased release cloudlet
# to retrieve active rules: 'akamai cloudlets retrieve --policy <policy_name>'
# we imported our existing policy using 'terraform import akamai_cloudlets_policy.phased_release grinwis_pr'
# with 'terraform show' we discovered that cloudlet_code = CD for phased release and this also showed the active rules
resource "akamai_cloudlets_policy" "phased_release" {
  name          = var.policy_name
  cloudlet_code = "CD"
  description   = "Terraform managed policy"
  group_id      = data.akamai_contract.contract.group_id

  # you can use the rules via data source data.akamai_cloudlets_phased_release_match_rule.example.json
  # or use local json file. We used an output rule to show all the rules in json format and placed that in a file
  # so you are able to maintain the phased release rules outside of this terraform file.
  # 
  # match_rules = file("rules/rules.json")
  # match_rules = data.akamai_cloudlets_phased_release_match_rule.to_deta.json
  # 
  # changed to templatefile() so we can use input vars to build json rules from template file
  match_rules = templatefile("rules/rules.tftpl", { to_deta_match_value = jsonencode(var.to_deta_match_value) })
}

# when using file() terraform is to quick so not activating the latest version
# let's do a lookup after modifying it and use that version
data "akamai_cloudlets_policy" "example" {
  policy_id = resource.akamai_cloudlets_policy.phased_release.id
}

# now activate the latest version by terraform on staging.
resource "akamai_cloudlets_policy_activation" "pr_staging_latest" {
  policy_id = resource.akamai_cloudlets_policy.phased_release.id
  network   = "staging"
  version   = split(":", data.akamai_cloudlets_policy.example.id)[1]
  # version               = resource.akamai_cloudlets_policy.phased_release.version
  associated_properties = var.hostnames
}
