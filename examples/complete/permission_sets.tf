locals {
  # We will use inline permission only in cases we dont want to use managed policies
  permission_sets = {
    Admin = {
      session_duration = "12"
      managed_policies = ["AdministratorAccess","job-function/ViewOnlyAccess"]
      inline_policy = "xray_access"
      customer_managed_policies = ["Customer_managed_permission"]
    }
  }
}

