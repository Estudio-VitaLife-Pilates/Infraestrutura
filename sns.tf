# 1. Criação do Tópico SNS para receber os alertas
resource "aws_sns_topic" "alerta_sns" {
  name = "AlertaSNS-Pilates"
}

# 2. Inscrição de e-mail no Tópico SNS
resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.alerta_sns.arn
  protocol  = "email"
  endpoint  = "adaman.santos@sptech.school.com"
}

# 3. Criação do Alarme do CloudWatch ("Alarme CPU") vinculado ao SNS
resource "aws_cloudwatch_metric_alarm" "alarme_cpu" {
  alarm_name          = "Alarme CPU"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80.0
  alarm_description   = "Alerta disparado quando a utilizacao de CPU for maior ou igual a 80%"
  
  dimensions = {
    InstanceId = "i-0d5c33e966620f38f" # ID da instância monitorada (ex: webinstance01)
  }

  alarm_actions = [aws_sns_topic.alerta_sns.arn]
}