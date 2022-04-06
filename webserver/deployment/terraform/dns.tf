data "aws_route53_zone" "main" {
  name = "aws.ivyplus.net"
}

resource "aws_route53_record" "web" {
  name    = "covid.${data.aws_route53_zone.main.name}"
  records = [aws_instance.web.public_ip]
  type    = "A"
  ttl     = 60
  zone_id = data.aws_route53_zone.main.zone_id
}

resource "aws_route53_record" "web6" {
  name    = "covid.${data.aws_route53_zone.main.name}"
  records = aws_instance.web.ipv6_addresses
  type    = "AAAA"
  ttl     = 60
  zone_id = data.aws_route53_zone.main.zone_id
}
