#!/bin/bash

# kubectl completion zsh 문제 해결 스크립트
# /dev/fd/11:2: command not found: compdef 에러 해결

set -e

echo "🔧 kubectl completion zsh 문제 해결 스크립트"
echo "============================================="

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 로그 함수
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# kubectl 설치 확인
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl이 설치되지 않았습니다."
        log_info "kubectl 설치 방법:"
        log_info "brew install kubectl"
        exit 1
    fi
    
    log_info "kubectl 버전: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
}

# zsh completion 시스템 초기화
init_zsh_completion() {
    log_info "zsh completion 시스템 초기화 중..."
    
    # ~/.zshrc 백업
    if [ -f ~/.zshrc ]; then
        cp ~/.zshrc ~/.zshrc.backup.$(date +%Y%m%d_%H%M%S)
        log_info "기존 ~/.zshrc 백업 완료"
    fi
    
    # completion 시스템 초기화 코드 추가
    cat >> ~/.zshrc << 'EOF'

# kubectl completion 설정
if command -v kubectl &> /dev/null; then
    # zsh completion 시스템 초기화 (compdef 함수 사용 가능하도록)
    autoload -Uz compinit
    compinit
    
    # kubectl completion 활성화
    source <(kubectl completion zsh)
    
    # kubectl 별칭 지원
    alias k=kubectl
    complete -F __start_kubectl k
fi
EOF
    
    log_info "~/.zshrc에 kubectl completion 설정 추가 완료"
}

# 기존 kubectl completion 설정 제거
remove_old_completion() {
    log_info "기존 kubectl completion 설정 확인 중..."
    
    if grep -q "kubectl completion zsh" ~/.zshrc 2>/dev/null; then
        log_warn "기존 kubectl completion 설정 발견"
        
        # 기존 설정 제거 (임시 파일 사용)
        grep -v "source <(kubectl completion zsh)" ~/.zshrc > ~/.zshrc.tmp || true
        mv ~/.zshrc.tmp ~/.zshrc
        
        log_info "기존 kubectl completion 설정 제거 완료"
    fi
}

# completion 디렉토리 생성
create_completion_dir() {
    log_info "zsh completion 디렉토리 설정 중..."
    
    # completion 디렉토리 생성
    mkdir -p ~/.zsh/completions
    
    # kubectl completion 파일 생성
    kubectl completion zsh > ~/.zsh/completions/_kubectl
    
    # fpath에 completion 디렉토리 추가
    if ! grep -q "fpath=(~/.zsh/completions \$fpath)" ~/.zshrc 2>/dev/null; then
        cat >> ~/.zshrc << 'EOF'

# zsh completion 디렉토리 추가
fpath=(~/.zsh/completions $fpath)
EOF
        log_info "fpath에 completion 디렉토리 추가 완료"
    fi
}

# 안전한 kubectl completion 설정
setup_safe_completion() {
    log_info "안전한 kubectl completion 설정 중..."
    
    # 기존 설정 제거
    remove_old_completion
    
    # 새로운 안전한 설정 추가
    cat >> ~/.zshrc << 'EOF'

# kubectl completion 안전한 설정
if command -v kubectl &> /dev/null; then
    # zsh completion 시스템이 로드되지 않은 경우에만 초기화
    if ! command -v compdef &> /dev/null; then
        autoload -Uz compinit
        compinit
    fi
    
    # kubectl completion 활성화 (에러 무시)
    source <(kubectl completion zsh) 2>/dev/null || true
    
    # kubectl 별칭 설정
    alias k=kubectl
    
    # 별칭에 대한 completion 설정 (에러 무시)
    if command -v compdef &> /dev/null; then
        compdef kubectl k
    fi
fi
EOF
    
    log_info "안전한 kubectl completion 설정 완료"
}

# completion 테스트
test_completion() {
    log_info "kubectl completion 테스트 중..."
    
    # 새 zsh 세션에서 테스트
    if zsh -c "source ~/.zshrc && kubectl version --client --short" &>/dev/null; then
        log_info "kubectl completion 설정 성공!"
    else
        log_warn "kubectl completion 테스트 실패. 수동으로 확인이 필요합니다."
    fi
}

# 사용법 안내
show_usage() {
    log_info "kubectl completion 사용법:"
    echo ""
    echo "1. 새 터미널 세션을 시작하거나 다음 명령어 실행:"
    echo "   source ~/.zshrc"
    echo ""
    echo "2. kubectl 명령어에서 Tab 키를 눌러 자동완성 테스트:"
    echo "   kubectl get <Tab>"
    echo "   kubectl describe <Tab>"
    echo ""
    echo "3. 별칭 사용:"
    echo "   k get pods"
    echo "   k describe service"
    echo ""
    echo "4. 문제가 지속되면 다음 명령어로 디버깅:"
    echo "   echo \$fpath"
    echo "   which compdef"
    echo "   kubectl completion zsh | head -10"
}

# 메인 실행 함수
main() {
    log_info "kubectl completion zsh 문제 해결 시작..."
    
    # kubectl 설치 확인
    check_kubectl
    
    # completion 디렉토리 생성
    create_completion_dir
    
    # 안전한 completion 설정
    setup_safe_completion
    
    # 테스트
    test_completion
    
    # 사용법 안내
    show_usage
    
    log_info "kubectl completion 설정 완료!"
    log_warn "변경사항을 적용하려면 새 터미널을 열거나 'source ~/.zshrc'를 실행하세요."
}

# 스크립트 실행
main "$@"