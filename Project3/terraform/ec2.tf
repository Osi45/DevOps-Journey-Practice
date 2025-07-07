resource "aws_key_pair" "project_key" {
  key_name   = var.key_name
  public_key = file("${path.module}/${var.key_name}.pub")
}

resource "aws_instance" "web_app" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public_subnet.id
  vpc_security_group_ids      = [aws_security_group.web_sg.id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.project_key.key_name
  iam_instance_profile        = aws_iam_instance_profile.ssm_profile.name
  user_data                   = file("${path.module}/filebeat-user-data.sh.tpl")

  tags = {
    Name = "${var.project_name}-web"
  }
}

resource "aws_instance" "monitoring" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.private_subnet.id
  vpc_security_group_ids      = [aws_security_group.monitoring_sg.id]
  key_name                    = aws_key_pair.project_key.key_name
  iam_instance_profile        = aws_iam_instance_profile.ssm_profile.name

  user_data = templatefile("${path.module}/monitoring-user-data.sh.tpl", {
    web_app_private_ip = aws_instance.web_app.private_ip
  })

  depends_on = [aws_instance.web_app] 

  tags = {
    Name = "${var.project_name}-monitoring"
  }
}
