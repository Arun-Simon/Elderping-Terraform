resource "aws_cloudfront_distribution" "main" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${var.project} production CDN"
  default_root_object = "index.html"
  aliases             = [var.domain_name]
  price_class         = "PriceClass_100"
  web_acl_id          = var.waf_web_acl_arn

  origin {
    domain_name = var.alb_dns_name
    origin_id   = "${var.project}-alb-origin"
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
    custom_header {
      name  = "X-Custom-Origin-Verify"
      value = var.origin_verify_secret
    }
  }

  default_cache_behavior {
    allowed_methods        = ["DELETE","GET","HEAD","OPTIONS","PATCH","POST","PUT"]
    cached_methods         = ["GET","HEAD"]
    target_origin_id       = "${var.project}-alb-origin"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    forwarded_values {
      query_string = true
      headers      = ["Host","Authorization","CloudFront-Forwarded-Proto"]
      cookies      { forward = "all" }
    }
    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 31536000
  }

  ordered_cache_behavior {
    path_pattern           = "/static/*"
    allowed_methods        = ["GET","HEAD"]
    cached_methods         = ["GET","HEAD"]
    target_origin_id       = "${var.project}-alb-origin"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    forwarded_values {
      query_string = false
      cookies      { forward = "none" }
    }
    min_ttl     = 86400
    default_ttl = 604800
    max_ttl     = 31536000
  }

  viewer_certificate {
    acm_certificate_arn      = var.acm_certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  dynamic "logging_config" {
    for_each = var.log_bucket_domain != "" ? [1] : []
    content {
      include_cookies = false
      bucket          = var.log_bucket_domain
      prefix          = "cloudfront-logs/"
    }
  }

  tags = merge(var.tags, { Name = "${var.project}-cloudfront" })
}