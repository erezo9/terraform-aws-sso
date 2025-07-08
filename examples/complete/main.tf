module "sso" {
    source = "../.."
    ous = local.ous
    accounts = local.accounts
    permission_sets = local.permission_sets
}