# Bootstrap은 로컬 백엔드를 사용합니다
# 이미 생성된 백엔드를 사용하려면 아래 주석을 해제하세요
#
# terraform {
#   backend "s3" {
#     bucket         = "goorm-popcorn-tfstate"
#     key            = "bootstrap/terraform.tfstate"
#     region         = "ap-northeast-2"
#     dynamodb_table = "goorm-popcorn-tfstate-lock"
#     encrypt        = true
#   }
# }
