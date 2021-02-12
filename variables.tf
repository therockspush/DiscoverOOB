variable "password" {
   description = "password"
   type = string
   }

variable "access_key" {
    type = string
}

variable "secret_key" {
    type = string
}


variable "region" {
  description = "The AWS region to deploy this module in"
  type        = string
  default     = "us-east-1"
}

variable "spoke_cidr" {
  description = "The CIDR range to be used for the VPC"
  type        = string
  default     = "10.16.17.0/24"
}

variable "transit_cidr" {
  description = "The CIDR range to be used for the VPC"
  type        = string
  default     = "10.93.92.0/23"
}

variable "account" {
  description = "The AWS account name, as known by the Aviatrix controller"
  type        = string
  default     = "AWSflott"
}


variable "transit_instance_size" {
  description = "AWS Instance size for the Aviatrix gateways"
  type        = string
  default     = "c5.xlarge"
}

variable "spoke_instance_size" {
  description = "AWS Instance size for the Aviatrix gateways"
  type        = string
  default     = "t3.small"
}

variable "fw_instance_size" {
  description = "AWS Instance size for the NGFW's"
  type        = string
  default     = "c5.xlarge"
}

variable "ha_gw" {
  description = "Boolean to determine if module will be deployed in HA or single mode"
  type        = bool
  
}



variable "attached" {
  description = "Boolean to determine if the spawned firewall instances will be attached on creation"
  type        = bool
  default     = true
}

variable "firewall_image" {
  description = "The firewall image to be used to deploy the NGFW's"
  type        = string
  default     = "Palo Alto Networks VM-Series Next-Generation Firewall Bundle 1"
}


variable "inspection_enabled" {
  description = "Set to false to disable inspection"
  type        = bool
  default     = true
}

variable "egress_enabled" {
  description = "Set to true to enable egress"
  type        = bool
  default     = false
}


variable "az1" {
  description = "Concatenates with region to form az names. e.g. eu-central-1a. Only used for insane mode"
  type        = string
  default     = "a"
}

variable "az2" {
  description = "Concatenates with region to form az names. e.g. eu-central-1b. Only used for insane mode"
  type        = string
  default     = "b"
}

variable "connected_transit" {
  description = "Set to false to disable connected transit."
  type        = bool
  default     = true
}


variable "hybrid_connection" {
  description = "Set to true to prepare Aviatrix transit for TGW connection."
  type        = bool
  default     = false
}


variable "learned_cidr_approval" {
  description = "Set to true to enable learned CIDR approval."
  type        = string
  default     = "false"
}

variable "active_mesh" {
  description = "Set to false to disable active mesh."
  type        = bool
  default     = true
}
