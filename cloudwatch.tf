resource "aws_cloudwatch_dashboard" "monitoramento_pilates" {
  dashboard_name = "monitoramentoPilates"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 6
        height = 6
        properties = {
          metrics = [
            [ "AWS/EC2", "CPUUtilization", "InstanceId", "i-0d5c33e966620f38f", { label = "webinstance01" } ],
            [ ".", ".", "InstanceId", "i-04711f892fcb19ed", { label = "webinstance02" } ]
          ]
          view    = "timeSeries"
          stacked = false
          region  = "us-east-1"
          title   = "Uso de CPU das instancias de web server"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 6
        y      = 0
        width  = 6
        height = 6
        properties = {
          metrics = [
            [ "AWS/EC2", "NetworkOut", "InstanceId", "i-AppServerId", { label = "NetworkOut" } ]
          ]
          view    = "timeSeries"
          stacked = false
          region  = "us-east-1"
          title   = "Saida de rede do AppServer"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 6
        height = 6
        properties = {
          metrics = [
            [ "AWS/EBS", "VolumeReadOps", "VolumeId", "vol-0197714d942f04a5d", { label = "VolumeReadOps" } ],
            [ ".", ".", "VolumeId", "vol-090f332b7bcea92f1", { label = "dbinstance vol-0d" } ]
          ]
          view    = "timeSeries"
          stacked = false
          region  = "us-east-1"
          title   = "Leitura do EBS do DbInstance"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 18
        y      = 0
        width  = 6
        height = 6
        properties = {
          metrics = [
            [ "AWS/EFS", "StorageBytes", "FileSystemId", "fs-example", { label = "StorageBytes" } ]
          ]
          view    = "timeSeries"
          stacked = false
          region  = "us-east-1"
          title   = "Uso do EFS"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 6
        height = 6
        properties = {
          metrics = [
            [ "AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", "app/my-alb/123456789", { label = "HTTPCode_ELB_5XX_Count" } ]
          ]
          view    = "timeSeries"
          stacked = false
          region  = "us-east-1"
          title   = "Erros de servidor do ALB (Erros 5xx)"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 6
        y      = 6
        width  = 6
        height = 6
        properties = {
          metrics = [
            [ "AWS/EC2", "CPUUtilization", "InstanceId", "i-AppServerId", { label = "CPUUtilization" } ]
          ]
          view    = "timeSeries"
          stacked = false
          region  = "us-east-1"
          title   = "Uso de CPU do AppServer"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 6
        height = 6
        properties = {
          metrics = [
            [ "AWS/Route53", "HealthCheckPercentage", "HealthCheckId", "example-id", "AvailabilityZone", "us-east-1b", { label = "us-east-1b" } ],
            [ ".", ".", ".", ".", "AvailabilityZone", "us-east-1a", { label = "us-east-1a" } ]
          ]
          view    = "timeSeries"
          stacked = false
          region  = "us-east-1"
          title   = "Saude do DNS por zona de disponibilidade"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 18
        y      = 6
        width  = 6
        height = 6
        properties = {
          metrics = [
            [ "AWS/ApplicationELB", "RequestCount", "AvailabilityZone", "us-east-1a", { label = "us-east-1a" } ],
            [ ".", ".", ".", "us-east-1b", { label = "us-east-1b" } ]
          ]
          view    = "timeSeries"
          stacked = false
          region  = "us-east-1"
          title   = "Requisicoes por zona de disponibilidade"
          period  = 300
        }
      }
    ]
  })
}