# Fetching AWS SSO instances. Assumes there's at least one instance.
data "aws_ssoadmin_instances" "this" {}

# Creating AWS SSO Permission Sets based on provided definitions.
resource "aws_ssoadmin_permission_set" "this" {
  for_each         = var.permission_sets
  name             = try(each.value.name, each.key)
  description      = try("${each.value.description}, This Permission Set was created by aws-sso terraform, do not delete", "This Permission Set was created by aws-sso terraform, do not delete")
  instance_arn     = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  relay_state      = try(each.value.relay_state, null)
  session_duration = "PT${try(each.value.session_duration, 9)}H"
}

# Attach each customer managed policy to the permission set in locals
resource "aws_ssoadmin_customer_managed_policy_attachment" "this" {
  for_each = {
    for entry in flatten([
      for perm_set_key, perm_set_value in var.permission_sets : [
        for index, policy in try(perm_set_value.customer_managed_policies, []) : {
          permission_set          = perm_set_key,
          customer_managed_policy = policy,
          unique_key              = "${perm_set_key}-${policy}"
        }
      ]
    ]) : entry.unique_key => entry
  }
  instance_arn       = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  permission_set_arn = aws_ssoadmin_permission_set.this[each.value.permission_set].arn
  customer_managed_policy_reference {
    name = each.value.customer_managed_policy
    path = "/"
  }
}
# Attach each managed policy to the permission set in locals
resource "aws_ssoadmin_managed_policy_attachment" "this" {
  for_each = {
    for entry in flatten([
      for perm_set_key, perm_set_value in var.permission_sets : [
        for index, policy in try(perm_set_value.managed_policies, []) : {
          permission_set     = perm_set_key,
          managed_policy_arn = policy,
          unique_key         = "${perm_set_key}-${policy}"
        }
      ]
    ]) : entry.unique_key => entry
  }
  instance_arn       = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  managed_policy_arn = "arn:aws:iam::aws:policy/${each.value.managed_policy_arn}"
  permission_set_arn = aws_ssoadmin_permission_set.this[each.value.permission_set].arn
}

# Create inline policy to the created permission sets. Policies are sourced from local files. there can only be one inline policy to a permission set
resource "aws_ssoadmin_permission_set_inline_policy" "this" {
  for_each = {
    for perm_set_key, perm_set_value in var.permission_sets :
    perm_set_key => {
      permission_set = perm_set_key,
      inline_policy  = perm_set_value.inline_policy
    }
    if try(perm_set_value.inline_policy, null) != null
  }
  inline_policy      = file("${path.module}/policies/${each.value.inline_policy}.json")
  instance_arn       = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  permission_set_arn = aws_ssoadmin_permission_set.this[each.value.permission_set].arn
}

# Get data on each group for the assignment from the accounts locals
data "aws_identitystore_group" "group" {
  for_each          = { for account_id, v in local.flattened_accounts : "${v.account_id}-${v.group_name}-${v.group_value}" => v }
  identity_store_id = data.aws_ssoadmin_instances.this.identity_store_ids[0]
  alternate_identifier {
    unique_attribute {
      attribute_path  = "DisplayName"
      attribute_value = each.value.group_value
    }
  }
}

# Get data on each user for the assignemnt from the accounts
data "aws_identitystore_user" "user" {
  for_each          = { for account_id, v in local.flattened_accounts_users : "${v.account_id}-${v.user_name}-${v.user_value}" => v }
  identity_store_id = data.aws_ssoadmin_instances.this.identity_store_ids[0]
  alternate_identifier {
    unique_attribute {
      attribute_path  = "UserName"
      attribute_value = each.value.user_value
    }
  }
}
output "user" {
  value = data.aws_identitystore_user.user
  
}

resource "aws_ssoadmin_account_assignment" "user_assignment" {
  for_each           = { for account_id, v in local.flattened_accounts_users : "${v.account_id}-${v.user_name}-${v.user_value}" => v }
  instance_arn       = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  principal_id       = data.aws_identitystore_user.user["${each.value.account_id}-${each.value.user_name}-${each.value.user_value}"].id
  principal_type     = "USER"
  target_id          = each.value.account_id
  target_type        = "AWS_ACCOUNT"
  permission_set_arn = aws_ssoadmin_permission_set.this[each.value.user_name].arn
}
#Assign each group from data to the permission set according to the locals map
resource "aws_ssoadmin_account_assignment" "assignment" {
  for_each           = { for account_id, v in local.flattened_accounts : "${v.account_id}-${v.group_name}-${v.group_value}" => v }
  instance_arn       = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  principal_id       = data.aws_identitystore_group.group["${each.value.account_id}-${each.value.group_name}-${each.value.group_value}"].id
  principal_type     = "GROUP"
  target_id          = each.value.account_id
  target_type        = "AWS_ACCOUNT"
  permission_set_arn = aws_ssoadmin_permission_set.this[each.value.group_name].arn
}

# Get data of each account under the specified OU
data "aws_organizations_organizational_unit_descendant_accounts" "accounts" {
  for_each  = var.ous
  parent_id = each.key
}

# Get data for each group sepcified in the ous permission
data "aws_identitystore_group" "ou_id" {
  for_each          = { for ou_id, v in local.flattened_ous : "${v.ou_id}-${v.account_id}-${v.group_name}-${v.group_value}" => v }
  identity_store_id = data.aws_ssoadmin_instances.this.identity_store_ids[0]
  alternate_identifier {
    unique_attribute {
      attribute_path  = "DisplayName"
      attribute_value = each.value.group_value
    }
  }
}
#Assign each group from data to the permission set according to the account under the ou from locals map
resource "aws_ssoadmin_account_assignment" "ou_assignment" {
  for_each           = { for ou_id, v in local.flattened_ous : "${v.ou_id}-${v.account_id}-${v.group_name}-${v.group_value}" => v }
  instance_arn       = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  principal_id       = data.aws_identitystore_group.ou_id["${each.value.ou_id}-${each.value.account_id}-${each.value.group_name}-${each.value.group_value}"].id
  principal_type     = "GROUP"
  target_id          = each.value.account_id
  target_type        = "AWS_ACCOUNT"
  permission_set_arn = aws_ssoadmin_permission_set.this[each.value.group_name].arn
  # default was 5m changed to 10 because of timeouts. need to test correct times for longer deployments
  timeouts {
    create = "10m"
    delete = "10m"
  }
}

resource "aws_ssoadmin_permissions_boundary_attachment" "this" {
  for_each = {
    for perm_set_key, perm_set_value in var.permission_sets :
    perm_set_key => {
      permission_set       = perm_set_key,
      permissions_boundary = perm_set_value.permissions_boundary
    }
    if try(perm_set_value.permissions_boundary, null) != null
  }

  instance_arn       = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  permission_set_arn = aws_ssoadmin_permission_set.this[each.value.permission_set].arn

  permissions_boundary {
    managed_policy_arn = each.value.permissions_boundary.type == "managed" ? "arn:aws:iam::aws:policy/${each.value.permissions_boundary.policy}" : null
    dynamic "customer_managed_policy_reference" {
      for_each = each.value.permissions_boundary.type == "customer_managed" ? [each.value.permissions_boundary] : []
      content {
        name = "${customer_managed_policy_reference.value.name}_Boundary"
        path = "/"
      }
    }
  }
}
