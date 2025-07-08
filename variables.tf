variable "accounts" {
  description = "map of accounts to produce permissions"
  type        = map(any)
  default     = {}
}

variable "ous" {
  description = "map of accounts to produce permissions"
  type        = map(any)
  default     = {}
}

variable "permission_sets" {
  description = "map of accounts to produce permissions"
  type        = map(any)
  default     = {}
}