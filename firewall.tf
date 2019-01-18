#Create a tenant NSGroup
resource "nsxt_ns_group" "tenant_nsg" {
  description  = "NSgroup provisioned by Terraform"
  display_name = "${var.tenant_name}-nsg"

  membership_criteria {
    target_type = "VirtualMachine"
    scope       = "tenant"
    tag         = "${var.tenant_name}"
  }
}

#Create Default Tenant Rules. Allow traffic within the tenant and outbound. Block inbound traffic.
resource "nsxt_firewall_section" "tenant_fs" {
  description  = "FS provisioned by Terraform"
  display_name = "${var.tenant_name}"

  applied_to {
    target_type = "NSGroup"
    target_id   = "${nsxt_ns_group.tenant_nsg.id}"
  }

  section_type = "LAYER3"
  stateful     = true

  rule {
    display_name = "Allow Intra Tenant Traffic"
    description  = "all traffic betwen tenant VMs is allowed"
    action       = "ALLOW"
    logged       = true
    ip_protocol  = "IPV4"
    direction    = "IN_OUT"

    source {
      target_type = "NSGroup"
      target_id   = "${nsxt_ns_group.tenant_nsg.id}"
    }

    destination {
      target_type = "NSGroup"
      target_id   = "${nsxt_ns_group.tenant_nsg.id}"
    }

  }

  rule {
    display_name = "Allow outbound Traffic"
    description  = "all outbound traffic is allowed"
    action       = "ALLOW"
    logged       = true
    ip_protocol  = "IPV4"
    direction    = "IN_OUT"

    source {
      target_type = "NSGroup"
      target_id   = "${nsxt_ns_group.tenant_nsg.id}"
    }
  }

  rule {
    display_name = "Block inbound Traffic"
    description  = "all inbound traffic is blocked"
    action       = "DROP"
    logged       = true
    ip_protocol  = "IPV4"
    direction    = "IN_OUT"

    destination {
      target_type = "NSGroup"
      target_id   = "${nsxt_ns_group.tenant_nsg.id}"
    }
  }
}
