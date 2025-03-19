variable "template_files" {
  description = "List of template files to render with their respective variables"
  type = list(object({
    path = string
    vars = map(any)
  }))
}
