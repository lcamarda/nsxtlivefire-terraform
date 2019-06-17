# Configure the VMware NSX-T Provider
provider "nsxt" {
  host                 = "${var.nsx_ip}"
  username             = "admin"
  password             = "${var.nsx_password}"
  allow_unverified_ssl = true
}


# Create the data sources we will need to refer to later
data "nsxt_transport_zone" "overlay_tz" {
  display_name = "OVERLAY-TZ"
}

data "nsxt_logical_tier0_router" "tier0_router" {
  display_name = "t0-sitea"
}

data "nsxt_edge_cluster" "edge_cluster" {
  display_name = "sitea-edge-cluster"
}


resource "nsxt_logical_switch" "web" {
  admin_state       = "UP"
  description       = "LS created by Terraform"
  display_name      = "OV-Web-Terraform-${var.tenant_name}"
  transport_zone_id = "${data.nsxt_transport_zone.overlay_tz.id}"
  replication_mode  = "MTEP"
}

resource "nsxt_logical_switch" "app" {
  admin_state       = "UP"
  description       = "LS created by Terraform"
  display_name      = "OV-App-Terraform-${var.tenant_name}"
  transport_zone_id = "${data.nsxt_transport_zone.overlay_tz.id}"
  replication_mode  = "MTEP"
}

resource "nsxt_logical_switch" "db" {
  admin_state       = "UP"
  description       = "LS created by Terraform"
  display_name      = "OV-Db-Terraform-${var.tenant_name}"
  transport_zone_id = "${data.nsxt_transport_zone.overlay_tz.id}"
  replication_mode  = "MTEP"
}
