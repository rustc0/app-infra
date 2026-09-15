output "public_ip" {
  description = "SSH here: ssh -i ~/.ssh/your-key.pem admin@<this>"
  value       = aws_instance.vm.public_ip
}

output "instance_id" {
  description = "The ID of the EC2 instance"
  value = aws_instance.vm.id
}