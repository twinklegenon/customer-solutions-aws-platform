##################################
# Interfaces
##################################

output "replica_identifier" {
  description = "Identifier of the DR read replica"
  value       = aws_db_instance.replica.identifier
}

output "replica_arn" {
  description = "ARN of the DR read replica"
  value       = aws_db_instance.replica.arn
}

output "replica_address" {
  description = "Host name of the DR read replica"
  value       = aws_db_instance.replica.address
}

output "alarm_topic_arn" {
  description = "SNS topic in the DR region that receives the replica lag alarm"
  value       = aws_sns_topic.alarms.arn
}
