output "vpc_id" {
  value = aws_vpc.demo.id
}

output "public_ec2_public_ip" {
  value = aws_instance.public.public_ip
}

output "private_ec2_private_ip" {
  value = aws_instance.private.private_ip
}

output "nat_gateway_public_ip" {
  value = aws_eip.nat.public_ip
}

output "website_url" {
  value = "http://${aws_instance.public.public_ip}"
}

output "ssh_to_bastion" {
  value = "ssh -i demo-key ec2-user@${aws_instance.public.public_ip}"
}

# Run "ssh-add demo-key" first so the key is available for both hops
output "ssh_to_private_via_bastion" {
  value = "ssh -J ec2-user@${aws_instance.public.public_ip} ec2-user@${aws_instance.private.private_ip}"
}
