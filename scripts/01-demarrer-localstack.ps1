# Démarre LocalStack avec application des permissions, puis prouve qu'elle est active.
# Le token est saisi sans écho : il n'est écrit ni dans un fichier ni dans la commande.

docker stop localstack 2>$null | Out-Null
docker rm localstack 2>$null | Out-Null
$s = Read-Host "Token LocalStack" -AsSecureString
$env:LOCALSTACK_AUTH_TOKEN = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($s))
docker run -d --name localstack -p 127.0.0.1:4566:4566 -e LOCALSTACK_AUTH_TOKEN -e ENFORCE_IAM=1 localstack/localstack
Start-Sleep -Seconds 20
docker ps --filter name=localstack --format "{{.Names}} {{.Status}}"

$env:AWS_ACCESS_KEY_ID = "test"
$env:AWS_SECRET_ACCESS_KEY = "test"
$env:AWS_DEFAULT_REGION = "eu-west-3"
$env:AWS_ENDPOINT_URL = "http://localhost:4566"
$ACC = aws sts get-caller-identity --query Account --output text
$ACC

# Preuve : un compte sans aucun droit doit être refusé (AccessDenied attendu)
aws iam create-user --user-name controle | Out-Null
$k = aws iam create-access-key --user-name controle --query 'AccessKey.[AccessKeyId,SecretAccessKey]' --output text
$AK, $SK = $k -split "\s+"
aws configure set aws_access_key_id $AK --profile controle
aws configure set aws_secret_access_key $SK --profile controle
aws configure set region eu-west-3 --profile controle
aws s3 ls --profile controle

aws iam delete-access-key --user-name controle --access-key-id $AK
aws iam delete-user --user-name controle
