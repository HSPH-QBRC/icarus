data "aws_route53_zone" "main" {
  name = "aws.ivyplus.net"
}

resource "aws_route53_record" "web" {
  name    = "covid.${data.aws_route53_zone.main.name}"
  type    = "A"
  zone_id = data.aws_route53_zone.main.zone_id
  alias {
    evaluate_target_health = true
    name                   = aws_lb.web.dns_name
    zone_id                = aws_lb.web.zone_id
  }
}

resource "aws_route53_record" "web6" {
  name    = "covid.${data.aws_route53_zone.main.name}"
  type    = "AAAA"
  zone_id = data.aws_route53_zone.main.zone_id
  alias {
    evaluate_target_health = true
    name                   = aws_lb.web.dns_name
    zone_id                = aws_lb.web.zone_id
  }
}
