locals {
  # Mapping of account IDs to groups within those accounts
  flattened_ous = flatten([
    for ou_id, ou_data in var.ous : [
      for group_name, group_value in ou_data.groups : [
        for curr_group in group_value : [
          for account in data.aws_organizations_organizational_unit_descendant_accounts.accounts[ou_id].accounts :
          {
            ou_id       = ou_id
            group_name  = group_name
            group_value = curr_group
            account_id  = account.id
          }
          if account.status == "ACTIVE" # filter only active accounts from the list
        ]
      ]
    ]
  ])
  flattened_accounts = flatten([
    for account_id, account_data in var.accounts : [
      for group_name, group_value in account_data.groups : [
        for curr_group in group_value : {
          account_id  = account_id
          group_name  = group_name
          group_value = curr_group
        }
      ]
    ]
  ])

  flattened_accounts_users = flatten([
    for account_id, account_data in var.accounts : [
      for user_name, user_value in try(account_data.users,[]) : [
        for curr_user in user_value : {
          account_id  = account_id
          user_name  = user_name
          user_value = curr_user
        }
      ]
    ]
  ])
}
