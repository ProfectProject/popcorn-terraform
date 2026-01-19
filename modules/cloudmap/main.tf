# Private DNS Namespace for Service Discovery
resource "aws_service_discovery_private_dns_namespace" "main" {
  name        = var.namespace_name
  description = "Service discovery namespace for ${var.project_name}"
  vpc         = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.project_name}-service-discovery"
  })
}

# Service Discovery Services
resource "aws_service_discovery_service" "api_gateway" {
  name = "api-gateway"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id

    dns_records {
      ttl  = 60
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_grace_period_seconds = 30

  tags = merge(var.tags, {
    Name = "${var.project_name}-api-gateway-service"
  })
}

resource "aws_service_discovery_service" "user_service" {
  name = "user-service"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id

    dns_records {
      ttl  = 60
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_grace_period_seconds = 30

  tags = merge(var.tags, {
    Name = "${var.project_name}-user-service-service"
  })
}

resource "aws_service_discovery_service" "store_service" {
  name = "store-service"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id

    dns_records {
      ttl  = 60
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_grace_period_seconds = 30

  tags = merge(var.tags, {
    Name = "${var.project_name}-store-service-service"
  })
}

resource "aws_service_discovery_service" "order_service" {
  name = "order-service"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id

    dns_records {
      ttl  = 60
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_grace_period_seconds = 30

  tags = merge(var.tags, {
    Name = "${var.project_name}-order-service-service"
  })
}

resource "aws_service_discovery_service" "payment_service" {
  name = "payment-service"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id

    dns_records {
      ttl  = 60
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_grace_period_seconds = 30

  tags = merge(var.tags, {
    Name = "${var.project_name}-payment-service-service"
  })
}

resource "aws_service_discovery_service" "qr_service" {
  name = "qr-service"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id

    dns_records {
      ttl  = 60
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_grace_period_seconds = 30

  tags = merge(var.tags, {
    Name = "${var.project_name}-qr-service-service"
  })
}