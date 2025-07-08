locals {
  # Mapping of account IDs to groups within those accounts
  ous = {
    "<ou_id>" = {
      groups = {
        "<admin_access>" = ["<groupa>"]
        "<dev_access>"        = ["<groupb>"]
      }
    }
  }
}