# Copyright (c) 2019, 2020 Oracle and/or its affiliates. All rights reserved.
# Licensed under the Universal Permissive License v 1.0 as shown at http://oss.oracle.com/licenses/upl.
# 

# Gets a list of Availability Domains
data "oci_identity_availability_domains" "ADs" {
  compartment_id = var.tenancy_ocid
}

data "oci_objectstorage_namespace" "user_namespace" {
  compartment_id = var.compartment_ocid
}

# Randoms
resource "random_string" "deploy_id" {
  length  = 4
  special = false
}

### Passwords using random_string instead of random_password to be compatible with ORM (Need to update random provider)
resource "random_string" "autonomous_database_wallet_password" {
  length           = 16
  special          = true
  min_upper        = 3
  min_lower        = 3
  min_numeric      = 3
  min_special      = 3
  override_special = "{}#^*<>[]%~"
}

resource "random_string" "autonomous_database_admin_password" {
  length           = 16
  special          = true
  min_upper        = 3
  min_lower        = 3
  min_numeric      = 3
  min_special      = 3
  override_special = "{}#^*<>[]%~"
}

data "oci_database_autonomous_database_wallet" "autonomous_database_wallet" {
  autonomous_database_id = oci_database_autonomous_database.mushop_autonomous_database.id
  password               = random_string.autonomous_database_wallet_password.result
  base64_encode_content  = "true"
}

data "oci_limits_services" "test_services" {
  compartment_id = var.tenancy_ocid

  filter {
    name   = "name"
    values = ["compute"]
  }
}

data "oci_limits_limit_values" "test_limit_values" {
  count          = length(data.oci_identity_availability_domains.ADs.availability_domains)
  compartment_id = var.tenancy_ocid
  service_name   = data.oci_limits_services.test_services.services.0.name

  availability_domain = data.oci_identity_availability_domains.ADs.availability_domains[count.index].name
  name                = "vm-standard-e2-1-micro-count"
  scope_type          = "AD"
}

resource "random_shuffle" "ad" {
  input        = [for ad in data.oci_identity_availability_domains.ADs.availability_domains : ad.name]
  result_count = 1
}

# Gets a list of supported images based on the shape, operating_system and operating_system_version provided
data "oci_core_images" "compute_images" {
  compartment_id           = var.compartment_ocid
  operating_system         = var.image_operating_system
  operating_system_version = var.image_operating_system_version
  shape                    = var.instance_shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

data "template_file" "mushop" {
  template = "${file("./scripts/node.sh")}"
}

data "oci_identity_tenancy" "tenant_details" {
  tenancy_id = var.tenancy_ocid

  provider = oci.current_region
}

data "oci_identity_regions" "home_region" {
  filter {
    name   = "key"
    values = [data.oci_identity_tenancy.tenant_details.home_region_key]
  }

  provider = oci.current_region
}

# Available Services
data "oci_core_services" "all_services" {
  filter {
    name   = "name"
    values = ["All .* Services In Oracle Services Network"]
    regex  = true
  }
}

locals {
  common_tags = {
    Reference = "Created by OCI QuickStart for Always-Free Tier"
  }
}
