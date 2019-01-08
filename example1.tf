data "vsphere_network" "terraform_switch1" {
  name          = "${nsxt_logical_switch.switch1.display_name}"
  datacenter_id = "${data.vsphere_datacenter.datacenter.id}"
}

resource "vsphere_virtual_machine" "lb-01a" {
  network_interface {
    network_id = "${data.vsphere_network.terraform_switch1.id}"
  }

  name             = "lb-01a"
  memory           = 2048
  resource_pool_id = "resgroup-27"
  folder           = "WebApp"
  guest_id         = "other3xLinux64Guest"
  scsi_type        = "lsilogic"
}

# configure some variables first
variable "nsx_ip" {
  default = "nsxmgr-01a.corp.local"
}

variable "nsx_password" {
  default = "VMware1!"
}

variable "nsx_tag_scope" {
  default = "project"
}

variable "nsx_tag" {
  default = "terraform-demo"
}

variable "nsx_t1_router_name" {
  default = "terraform-demo-router"
}

variable "nsx_t1_ip" {
  default = "172.19.1.1/24"
}

variable "nsx_switch_name" {
  default = "terraform-demo-ls"
}

variable "vsphere_user" {
  default = "administrator@vsphere.local"
}

variable "vsphere_password" {
  default = "VMware1!"
}

variable "vsphere_server" {
  default = "vcsa-01a.corp.local"
}

# Configure the VMware NSX-T Provider
provider "nsxt" {
  host                 = "${var.nsx_ip}"
  username             = "admin"
  password             = "${var.nsx_password}"
  allow_unverified_ssl = true
}

provider "vsphere" {
  user           = "${var.vsphere_user}"
  password       = "${var.vsphere_password}"
  vsphere_server = "${var.vsphere_server}"

  # If you have a self-signed cert
  allow_unverified_ssl = true
}

# Create the data sources we will need to refer to later
data "nsxt_transport_zone" "overlay_tz" {
  display_name = "OVERLAY-TZ"
}

data "nsxt_logical_tier0_router" "tier0_router" {
  display_name = "t0-infrastructure-SiteA"
}

data "nsxt_edge_cluster" "edge_cluster1" {
  display_name = "edge-cluster-1-SiteA"
}

# Create NSX-T Logical Switch
resource "nsxt_logical_switch" "switch1" {
  admin_state       = "UP"
  description       = "LS created by Terraform"
  display_name      = "${var.nsx_switch_name}"
  transport_zone_id = "${data.nsxt_transport_zone.overlay_tz.id}"
  replication_mode  = "MTEP"

  tag {
    scope = "${var.nsx_tag_scope}"
    tag   = "${var.nsx_tag}"
  }

  tag {
    scope = "tenant"
    tag   = "second_example_tag"
  }
}

# Create T1 router
resource "nsxt_logical_tier1_router" "tier1_router" {
  description                 = "Tier1 router provisioned by Terraform"
  display_name                = "${var.nsx_t1_router_name}"
  failover_mode               = "PREEMPTIVE"
  edge_cluster_id             = "${data.nsxt_edge_cluster.edge_cluster1.id}"
  enable_router_advertisement = true
  advertise_connected_routes  = true
  advertise_static_routes     = true
  advertise_nat_routes        = true

  tag {
    scope = "${var.nsx_tag_scope}"
    tag   = "${var.nsx_tag}"
  }
}

# Create a port on the T0 router. We will connect the T1 router to this port
resource "nsxt_logical_router_link_port_on_tier0" "link_port_tier0" {
  description       = "TIER0_PORT1 provisioned by Terraform"
  display_name      = "TIER0_PORT1"
  logical_router_id = "${data.nsxt_logical_tier0_router.tier0_router.id}"

  tag {
    scope = "${var.nsx_tag_scope}"
    tag   = "${var.nsx_tag}"
  }
}

# Create a T1 uplink port and connect it to T0 router
resource "nsxt_logical_router_link_port_on_tier1" "link_port_tier1" {
  description                   = "TIER1_PORT1 provisioned by Terraform"
  display_name                  = "TIER1_PORT1"
  logical_router_id             = "${nsxt_logical_tier1_router.tier1_router.id}"
  linked_logical_router_port_id = "${nsxt_logical_router_link_port_on_tier0.link_port_tier0.id}"

  tag {
    scope = "${var.nsx_tag_scope}"
    tag   = "${var.nsx_tag}"
  }
}

# Create a switchport on our logical switch
resource "nsxt_logical_port" "logical_port1" {
  admin_state       = "UP"
  description       = "LP1 provisioned by Terraform"
  display_name      = "LP1"
  logical_switch_id = "${nsxt_logical_switch.switch1.id}"

  tag {
    scope = "${var.nsx_tag_scope}"
    tag   = "${var.nsx_tag}"
  }
}

# Create downlink port on the T1 router and connect it to the switchport we created earlier
resource "nsxt_logical_router_downlink_port" "downlink_port" {
  description                   = "DP1 provisioned by Terraform"
  display_name                  = "DP1"
  logical_router_id             = "${nsxt_logical_tier1_router.tier1_router.id}"
  linked_logical_switch_port_id = "${nsxt_logical_port.logical_port1.id}"
  ip_address                    = "${var.nsx_t1_ip}"

  tag {
    scope = "${var.nsx_tag_scope}"
    tag   = "${var.nsx_tag}"
  }
}

# Create NS Group Web
resource "nsxt_ns_group" "web" {
  description  = "NSgroup provisioned by Terraform"
  display_name = "tf-web"

  membership_criteria {
    target_type = "VirtualMachine"
    scope       = "webapp"
    tag         = "web"
  }

  tag {
    scope = "${var.nsx_tag_scope}"
    tag   = "${var.nsx_tag}"
  }
}

# Create NS Group App
resource "nsxt_ns_group" "app" {
  description  = "NSgroup provisioned by Terraform"
  display_name = "tf-app"

  membership_criteria {
    target_type = "VirtualMachine"
    scope       = "webapp"
    tag         = "app"
  }

  tag {
    scope = "${var.nsx_tag_scope}"
    tag   = "${var.nsx_tag}"
  }
}

# Create NS Group Db
resource "nsxt_ns_group" "db" {
  description  = "NSgroup provisioned by Terraform"
  display_name = "tf-db"

  membership_criteria {
    target_type = "VirtualMachine"
    scope       = "webapp"
    tag         = "db"
  }

  tag {
    scope = "${var.nsx_tag_scope}"
    tag   = "${var.nsx_tag}"
  }
}

# Create NS Group Webapp
resource "nsxt_ns_group" "webapp" {
  description  = "NSgroup provisioned by Terraform"
  display_name = "tf-webapp"

  membership_criteria {
    target_type = "VirtualMachine"
    scope       = "webapp"
  }

  tag {
    scope = "${var.nsx_tag_scope}"
    tag   = "${var.nsx_tag}"
  }
}

# Collect NS Service info
data "nsxt_ns_service" "dns" {
  display_name = "DNS"
}

data "nsxt_ns_service" "https" {
  display_name = "HTTPS"
}

data "nsxt_ns_service" "http" {
  display_name = "HTTP"
}

resource "nsxt_l4_port_set_ns_service" "tomcat" {
  description       = "Service provisioned by Terraform"
  display_name      = "tf-tomcat"
  protocol          = "TCP"
  destination_ports = ["8443"]

  tag {
    scope = "${var.nsx_tag_scope}"
    tag   = "${var.nsx_tag}"
  }
}

resource "nsxt_firewall_section" "webapp" {
  description  = "FS provisioned by Terraform"
  display_name = "Web App"

  tag {
    scope = "${var.nsx_tag_scope}"
    tag   = "${var.nsx_tag}"
  }

  applied_to {
    target_type = "NSGroup"
    target_id   = "${nsxt_ns_group.webapp.id}"
  }

  section_type = "LAYER3"
  stateful     = true

  rule {
    display_name = "any to web"
    description  = "all traffic to web is allowed on port 443"
    action       = "ALLOW"
    logged       = true
    ip_protocol  = "IPV4"
    direction    = "IN_OUT"

    destination {
      target_type = "NSGroup"
      target_id   = "${nsxt_ns_group.web.id}"
    }

    service {
      target_type = "NSService"
      target_id   = "${data.nsxt_ns_service.https.id}"
    }
  }

  rule {
    display_name = "web to app"
    description  = "I"
    action       = "ALLOW"
    logged       = true
    ip_protocol  = "IPV4"
    direction    = "IN_OUT"

    source {
      target_type = "NSGroup"
      target_id   = "${nsxt_ns_group.web.id}"
    }

    destination {
      target_type = "NSGroup"
      target_id   = "${nsxt_ns_group.app.id}"
    }

    service {
      target_type = "NSService"
      target_id   = "${nsxt_l4_port_set_ns_service.tomcat.id}"
    }
  }

  rule {
    display_name = "app to db"
    description  = ""
    action       = "ALLOW"
    logged       = true
    ip_protocol  = "IPV4"
    direction    = "IN_OUT"

    source {
      target_type = "NSGroup"
      target_id   = "${nsxt_ns_group.app.id}"
    }

    destination {
      target_type = "NSGroup"
      target_id   = "${nsxt_ns_group.db.id}"
    }

    service {
      target_type = "NSService"
      target_id   = "${data.nsxt_ns_service.http.id}"
    }
  }

  rule {
    display_name = "deny ANY ANY"
    description  = ""
    action       = "DROP"
    logged       = true
    ip_protocol  = "IPV4"
    direction    = "IN_OUT"
  }
}

data "vsphere_datacenter" "datacenter" {
  name = "Site-A"
}

data "vsphere_virtual_machine" "web-01a" {
  name          = "web-01a"
  datacenter_id = "${data.vsphere_datacenter.datacenter.id}"
}

data "vsphere_virtual_machine" "web-02a" {
  name          = "web-02a"
  datacenter_id = "${data.vsphere_datacenter.datacenter.id}"
}

data "vsphere_virtual_machine" "app-01a" {
  name          = "app-01a"
  datacenter_id = "${data.vsphere_datacenter.datacenter.id}"
}

data "vsphere_virtual_machine" "db-01a" {
  name          = "db-01a"
  datacenter_id = "${data.vsphere_datacenter.datacenter.id}"
}

resource "nsxt_vm_tags" "web-01a_tags" {
  instance_id = "${data.vsphere_virtual_machine.web-01a.id}"

  tag {
    scope = "webapp"
    tag   = "web"
  }
}

resource "nsxt_vm_tags" "web-02a_tags" {
  instance_id = "${data.vsphere_virtual_machine.web-02a.id}"

  tag {
    scope = "webapp"
    tag   = "web"
  }
}

resource "nsxt_vm_tags" "app-01a_tags" {
  instance_id = "${data.vsphere_virtual_machine.app-01a.id}"

  tag {
    scope = "webapp"
    tag   = "app"
  }
}

resource "nsxt_vm_tags" "db-01a_tags" {
  instance_id = "${data.vsphere_virtual_machine.db-01a.id}"

  tag {
    scope = "webapp"
    tag   = "db"
  }
}
