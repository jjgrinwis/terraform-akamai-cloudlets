variable "hostnames" {
  description = "One or more hostnames that's using this cloudlet"
  type        = list(string)
  validation {
    condition     = length(var.hostnames) > 0
    error_message = "At least one hostname should be provided, it can't be empty."
  }
}

variable "policy_name" {
  description = "The Edge Redirector cloudlet policy name"
  type        = string
}

variable "group_name" {
  description = "Akamai group to create this resource in"
  type        = string
}

