data "aws_iam_policy_document" "assume_role" {
  count = module.context.enabled ? length(keys(var.principals)) : 0

  statement {
    effect  = "Allow"
    actions = var.assume_role_actions

    principals {
      type        = element(keys(var.principals), count.index)
      identifiers = var.principals[element(keys(var.principals), count.index)]
    }

    dynamic "condition" {
      for_each = var.assume_role_conditions
      content {
        test     = condition.value.test
        variable = condition.value.variable
        values   = condition.value.values
      }
    }
  }
}

data "aws_iam_policy_document" "assume_role_aggregated" {
  count                     = module.context.enabled ? 1 : 0
  override_policy_documents = data.aws_iam_policy_document.assume_role.*.json
}

resource "aws_iam_role" "default" {
  count                = module.context.enabled ? 1 : 0
  name                 = var.use_fullname ? module.context.id : module.context.name
  assume_role_policy   = var.assume_role_policy_document_override != null ? var.assume_role_policy_document_override : join("", data.aws_iam_policy_document.assume_role_aggregated.*.json)
  description          = var.role_description
  max_session_duration = var.max_session_duration
  permissions_boundary = var.permissions_boundary
  path                 = var.path
  tags                 = var.tags_enabled ? module.context.tags : null

  dynamic "inline_policy" {
    for_each = var.in_line_policies
    content {
      name = inline_policy.key
      policy = inline_policy.value
    }
  }
}

data "aws_iam_policy_document" "default" {
  count                     = module.context.enabled && var.policy_document_count > 0 ? 1 : 0
  override_policy_documents = var.policy_documents
}

resource "aws_iam_policy" "default" {
  count       = module.context.enabled && var.policy_document_count > 0 ? 1 : 0
  name        = "${module.context.id}-policy"
  description = var.policy_description
  policy      = join("", data.aws_iam_policy_document.default.*.json)
  path        = var.path
  tags        = var.tags_enabled ? module.context.tags : null
}

resource "aws_iam_role_policy_attachment" "default" {
  count      = module.context.enabled && var.policy_document_count > 0 ? 1 : 0
  role       = join("", aws_iam_role.default.*.name)
  policy_arn = join("", aws_iam_policy.default.*.arn)
}

resource "aws_iam_role_policy_attachment" "managed" {
  for_each   = module.context.enabled ? var.managed_policy_arns : []
  role       = join("", aws_iam_role.default.*.name)
  policy_arn = each.key
}

resource "aws_iam_instance_profile" "default" {
  count = module.context.enabled && var.instance_profile_enabled ? 1 : 0
  name  = module.context.id
  role  = join("", aws_iam_role.default.*.name)
}
