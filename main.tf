provider "aviatrix" {
  controller_ip = "10.30.0.14"
  username = "admin"
  password = var.password
  skip_version_validation = true
  
  }

provider "aws" {
  region     = var.region
  access_key = var.access_key
  secret_key = var.secret_key
}

resource "aviatrix_vpc" "aws_transit_firenet_vpc" {
  cloud_type           = 1
  account_name         = var.account
  region               = var.region
  name                 = "OOBTransitFirenetVPC"
  cidr                 = var.transit_cidr
  aviatrix_transit_vpc = false
  aviatrix_firenet_vpc = true
  enable_private_oob_subnet = true
}

resource "aviatrix_vpc" "aws_spoke_vpc" {
  cloud_type           = 1
  account_name         = var.account
  region               = var.region
  name                 = "aws-spokeOOBVPC"
  cidr                 = var.spoke_cidr
  aviatrix_transit_vpc = false
  aviatrix_firenet_vpc = false
  enable_private_oob_subnet = true
}


resource "aviatrix_aws_tgw" "oobtgw" {
  account_name                      = var.account
 
  aws_side_as_number                = "64512"
  manage_vpc_attachment             = false
  manage_transit_gateway_attachment = false
  region                            = var.region
  tgw_name                          = "OOBTGWNVA"

  security_domains {
    connected_domains    = [
      "Default_Domain",
      "Shared_Service_Domain"
      
    ]
    security_domain_name = "Aviatrix_Edge_Domain"
  }

  security_domains {
    connected_domains    = [
      "Aviatrix_Edge_Domain",
      "Shared_Service_Domain"
    ]    
    security_domain_name = "Default_Domain"
  }

  security_domains {
    connected_domains    = [
      "Aviatrix_Edge_Domain",
      "Default_Domain"
    ]
    security_domain_name = "Shared_Service_Domain"
  }
}

resource "aviatrix_aws_tgw_vpc_attachment" "default_route_vpc_attachment" {

  tgw_name             = aviatrix_aws_tgw.oobtgw.tgw_name
  region               = var.region
  security_domain_name = "Shared_Service_Domain"
  vpc_account_name     = var.account
  vpc_id               = data.aws_vpc.NATGWVPC.id
  customized_route_advertisement = "0.0.0.0/0"

  depends_on = [aviatrix_aws_tgw.oobtgw]


}

resource "aviatrix_aws_tgw_vpc_attachment" "Transit_aws_tgw_vpc_attachment" {
  tgw_name             = aviatrix_aws_tgw.oobtgw.tgw_name
  region               = var.region
  security_domain_name = "Shared_Service_Domain"
  vpc_account_name     = var.account
  vpc_id               = aviatrix_vpc.aws_transit_firenet_vpc.vpc_id
  subnets              = "${data.aws_subnet.selected_oob_subnet.id} , ${data.aws_subnet.selected_oob_subnet2.id}"
  route_tables         = data.aws_route_table.TransitprivateRT.id

  depends_on = [aviatrix_vpc.aws_transit_firenet_vpc]

}


resource "aviatrix_aws_tgw_vpc_attachment" "Spoke_aws_tgw_vpc_attachment" {
  tgw_name             = aviatrix_aws_tgw.oobtgw.tgw_name
  region               = var.region
  security_domain_name = "Shared_Service_Domain"
  vpc_account_name     = var.account
  vpc_id               = aviatrix_vpc.aws_spoke_vpc.vpc_id
  subnets              = "${data.aws_subnet.spokeselected.id} , ${data.aws_subnet.spokeselected2.id}"
  route_tables         = data.aws_route_table.spokeprivateRT.id

depends_on = [aviatrix_vpc.aws_spoke_vpc]

}


resource "aviatrix_transit_gateway" "transit_firenet_gw" {
  cloud_type               = 1
  account_name             = var.account
  gw_name                  = "transitgw"
  vpc_id                   = aviatrix_vpc.aws_transit_firenet_vpc.vpc_id
  vpc_reg                  = var.region
  gw_size                  = var.transit_instance_size
  subnet                   = cidrsubnet("${aviatrix_vpc.aws_transit_firenet_vpc.cidr}", 3, 2)
  single_az_ha             = false
  enable_transit_firenet   = true
  enable_private_oob       = true
  oob_management_subnet    = data.aws_subnet.selected_oob_subnet.cidr_block
  oob_availability_zone    = "us-east-1a"
  connected_transit        = var.connected_transit
  
  
  tag_list                 = [
    "name:transitgw",
  ]
  enable_active_mesh       = true
  enable_hybrid_connection = false
  

  depends_on = [aviatrix_aws_tgw_vpc_attachment.Transit_aws_tgw_vpc_attachment]
}




resource "aviatrix_spoke_gateway" "oobspokegw" {
  cloud_type         = 1
  account_name       = var.account
  gw_name            = "oobspokegw"
  vpc_id             = aviatrix_vpc.aws_spoke_vpc.vpc_id
  vpc_reg            = var.region
  gw_size            = var.spoke_instance_size
  subnet             = cidrsubnet("${aviatrix_vpc.aws_spoke_vpc.cidr}", 2, 3)
  enable_active_mesh = true
  enable_private_oob       = true
  oob_management_subnet    = data.aws_subnet.spokeselected.cidr_block
  oob_availability_zone    = "us-east-1a"

  tag_list           = [
    "name:oobspokegw",
  ]
  depends_on = [aviatrix_aws_tgw_vpc_attachment.Spoke_aws_tgw_vpc_attachment]

}

resource "aviatrix_spoke_transit_attachment" "spoke_attachment" {
    spoke_gw_name   = aviatrix_spoke_gateway.oobspokegw.gw_name
    transit_gw_name = aviatrix_transit_gateway.transit_firenet_gw.gw_name

  

}




resource "aviatrix_firewall_instance" "test_firewall_instance" {
  vpc_id            = aviatrix_vpc.aws_transit_firenet_vpc.vpc_id
  firenet_gw_name   = aviatrix_transit_gateway.transit_firenet_gw.gw_name
  firewall_name     = "avx-firewall-instance"
  firewall_image    = var.firewall_image
  firewall_size     = var.fw_instance_size
  management_subnet = data.aws_subnet.fwMGMTa.cidr_block
  egress_subnet     = data.aws_subnet.fwEgressa.cidr_block
  
  depends_on = [aviatrix_transit_gateway.transit_firenet_gw]
}

resource "aviatrix_firenet" "test_firenet" {
  vpc_id                               = aviatrix_vpc.aws_transit_firenet_vpc.vpc_id
  inspection_enabled                   = true
  egress_enabled                       = false
  manage_firewall_instance_association  = false

  depends_on = [aviatrix_transit_gateway.transit_firenet_gw]
}

resource "aviatrix_firewall_instance_association" "firewall_instance_association_1" {
    vpc_id               = aviatrix_vpc.aws_transit_firenet_vpc.vpc_id
    firenet_gw_name      = aviatrix_transit_gateway.transit_firenet_gw.gw_name
    instance_id          = aviatrix_firewall_instance.test_firewall_instance.instance_id
    vendor_type          = "Generic"
    firewall_name        = aviatrix_firewall_instance.test_firewall_instance.firewall_name
    lan_interface        = aviatrix_firewall_instance.test_firewall_instance.lan_interface
    management_interface = aviatrix_firewall_instance.test_firewall_instance.management_interface
    egress_interface     = aviatrix_firewall_instance.test_firewall_instance.egress_interface
    attached             = true
  
  depends_on = [aviatrix_firewall_instance.test_firewall_instance]
  }

resource "aviatrix_transit_firenet_policy" "test_transit_firenet_policy" {
  transit_firenet_gateway_name = aviatrix_transit_gateway.transit_firenet_gw.gw_name
  inspected_resource_name      = "SPOKE:oobspokegw"

  depends_on = [aviatrix_firewall_instance_association.firewall_instance_association_1]
}


data "aws_vpc" "selectedTransit" {
  filter {
    name = "tag:Name"
    values = ["OOBTransitFirenetVPC"]
  }

  depends_on = [aviatrix_vpc.aws_transit_firenet_vpc]
}


data "aws_subnet" "selected_oob_subnet" {
  vpc_id = "${data.aws_vpc.selectedTransit.id}"
  
  filter {
    name = "tag:Name"
    values = ["*Private-OOB-*1a"]
  }

  depends_on = [aviatrix_vpc.aws_transit_firenet_vpc]
}

data "aws_subnet" "selected_oob_subnet2" {
  vpc_id = "${data.aws_vpc.selectedTransit.id}"
  
  filter {
    name = "tag:Name"
    values = ["*Private-OOB-*1b"]
  }

  depends_on = [aviatrix_vpc.aws_transit_firenet_vpc]
}

data "aws_subnet" "fwMGMTa" {
  vpc_id = "${data.aws_vpc.selectedTransit.id}"
  
  filter {
    name = "tag:Name"
    values = ["*mgmt*-1a"]
  }

  depends_on = [aviatrix_vpc.aws_transit_firenet_vpc]
}

data "aws_subnet" "fwEgressa" {
  vpc_id = "${data.aws_vpc.selectedTransit.id}"
  
  filter {
    name = "tag:Name"
    values = ["*egress*-1a"]
  }

  depends_on = [aviatrix_vpc.aws_transit_firenet_vpc]
}

data "aws_route_table" "TransitprivateRT" {
    vpc_id = "${data.aws_vpc.selectedTransit.id}"

    filter {
        name = "tag:Name"
        values = ["*Private-OOB*"]
    }

    depends_on = [aviatrix_vpc.aws_transit_firenet_vpc]
}


data "aws_vpc" "selectedSpoke" {
  filter {
    name = "tag:Name"
    values = ["aws-spokeOOBVPC"]
  }

  depends_on = [aviatrix_vpc.aws_spoke_vpc]
}

data "aws_subnet" "spokeselected" {
  vpc_id = "${data.aws_vpc.selectedSpoke.id}"
  
  filter {
    name = "tag:Name"
    values = ["*Private-OOB*-1a"]
  }

  depends_on = [aviatrix_vpc.aws_spoke_vpc]
}

data "aws_subnet" "spokeselected2" {
  vpc_id = "${data.aws_vpc.selectedSpoke.id}"
  
  filter {
    name = "tag:Name"
    values = ["*Private-OOB-*1b"]
  }

  depends_on = [aviatrix_vpc.aws_spoke_vpc]
}

data "aws_route_table" "spokeprivateRT" {
    vpc_id = "${data.aws_vpc.selectedSpoke.id}"

    filter {
        name = "tag:Name"
        values = ["*Private-OOB*"]
    }

    depends_on = [aviatrix_vpc.aws_spoke_vpc]
}


data "aws_vpc" "NATGWVPC" {

  filter {
    name = "tag:Name"
    values = ["DefaultNATVPCNVa"]
  }
}

