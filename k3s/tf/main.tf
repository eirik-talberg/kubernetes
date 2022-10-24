terraform {
  required_providers {
    
  }
}

module "k3s" {
    source  = "xunleii/k3s/module"
    version = "3.2.0"
    k3s_version = "v1.25.2+k3s1"
    use_sudo = true

    servers = {
        k3s-01 = {
            ip = "10.0.69.13"
            connection = {
                user = "taldev"
                private_key = "${file("~/.ssh/id_rsa")}"
    
           }
        }
    }  
}
