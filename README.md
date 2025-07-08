# AWS SSO - Terraform Module

AWS SSO is a sso module that helps you define multiple permssions sets and assign the to accounts and ous in a simple way in iam identity center


## Usage

## SSO 
You need to create 3 locals which contain data about the permission sets ous and accounts
for accounts you may assign either user or group for a permission set, and multiple groups for each permission set
```hcl
  accounts = {
    "<account_number" = {
      groups = {
        "finops" = ["finopsgroup"]
      }
      users = {
        "dev" = ["myuser"]
      }
    }
  }
```
for ous you may a group for a permission set, and multiple groups for each permission set
```hcl
  ous = {
    "<ou_id>" = {
      groups = {
        "Admin" = ["myadminGroup"]
        "developer"        = ["mydevsa","mydevsb"]
      }
    }
  }
```

and permission sets which help define the neccasery permission for the role
```hcl
  permission_sets = {
    Admin = {
      session_duration = "12"
      managed_policies = ["AdministratorAccess","job-function/ViewOnlyAccess"]
      inline_policy = "xray_access"
      customer_managed_policies = ["Customer_managed_permission"]
    }
  }
```