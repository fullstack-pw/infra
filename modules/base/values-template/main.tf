/**
 * Base Values Template Module
 *
 * This module standardizes the rendering of Helm chart values templates.
 */

locals {
  values_rendered = [
    for template_file in var.template_files : templatefile(
      template_file.path,
      template_file.vars
    )
  ]
}
