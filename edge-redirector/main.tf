# our edge redirector cloudlet test
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
data "akamai_cloudlets_edge_redirector_match_rule" "redirect_rules" {
  match_rules {
    name                      = "to_akamai"
    match_url                 = "example.com"
    redirect_url              = "https://www.akamai.com"
    status_code               = 301
    use_incoming_query_string = false
    use_relative_url          = "none"
  }
}

# this edge redirector policy has been created from scratch via Terraform
# after our initial deploy we created a more complex rule via the portal
# we then run 'terraform refresh' to refresh the state and used 'terraform show' to show our new rules
# json format to be used in our template via: 'akamai cloudlets retrieve --policy grinwis_er'
resource "akamai_cloudlets_policy" "edge_redirector" {
  name          = var.policy_name
  cloudlet_code = "ER"
  description   = "Terraform managed policy"
  group_id      = data.akamai_contract.contract.group_id

  # you can use the rules via data source data.akamai_cloudlets_phased_release_match_rule.example.json
  # or use local json file. We used an output rule to show all the rules in json format and placed that in a file
  # so you are able to maintain the phased release rules outside of this terraform file.
  # 
  match_rules = file("rules/rules.json")
  # match_rules = data.akamai_cloudlets_edge_redirector_match_rule.redirect_rules.json
  # 
  # changed to templatefile() so we can use input vars to build json rules from template file
  #  match_rules = templatefile("rules/rules.tftpl", { to_deta_match_value = jsonencode(var.to_deta_match_value) })
}

# when using file() terraform is to quick so not activating the latest version
# let's do a lookup after modifying it and use that version
data "akamai_cloudlets_policy" "example" {
  policy_id = resource.akamai_cloudlets_policy.edge_redirector.id
}

# now activate the latest version by terraform on staging.
resource "akamai_cloudlets_policy_activation" "er_staging_latest" {
  policy_id             = resource.akamai_cloudlets_policy.edge_redirector.id
  network               = "staging"
  version               = split(":", data.akamai_cloudlets_policy.example.id)[1]
  associated_properties = var.hostnames
}
