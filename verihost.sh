#!/bin/bash

# ================================
# VeriHost - VPN Host Analyzer
# by Fillipe & ChatGPT
# ================================

clear
# Arte ASCII de abertura
echo "=============================================="
echo "  VPN Host Analyzer - Fillipe & ChatGPT"
echo "=============================================="
echo " _   _           _ _   _           _   "
echo "| | | |         (_) | | |         | |  "
echo "| | | | ___ _ __ _| |_| | ___  ___| |_ "
echo "| | | |/ _ \\ '__| |  _  |/ _ \\/ __| __|"
echo "\\ \\_/ /  __/ |  | | | | | (_) \\__ \\ |_ "
echo " \\___/ \\___|_|  |_|_| |_|\\___/|___/\\__|"
echo "                                       "
echo "=============================================="
echo ""

# Entrada dos hosts
read -p "Insira os hosts separados por espaço: " -a hosts

# Lista para armazenar hosts bons
bons_hosts=()

# Loop principal para cada host
for host in "${hosts[@]}"; do
  echo ""
  echo "🔍 Testando: $host"
  echo "----------------------------------------------"

  # Variáveis de status
  responde_ping="false"
  tls_valido="false"
  redir_http="false"
  redir_https="false"
  porta80_aberta="false"
  porta443_aberta="false"

  # Teste de ping
  echo "📶 1) Verificando se responde ao ping..."
  ping -c 1 -W 3 $host > /dev/null 2>&1
  if [ $? -eq 0 ]; then
    echo "✅ Host responde ao ping"
    responde_ping="true"
  else
    echo "❌ Não responde (offline ou ICMP bloqueado)"
  fi

  # Teste TLS/SNI em portas 443 e 80
  for port in 443 80; do
    echo ""
    echo "🔐 2) Testando TLS/SNI na porta $port..."
    timeout 5 openssl s_client -connect $host:$port -servername $host < /dev/null 2>/dev/null | grep -q "BEGIN CERTIFICATE"
    if [ $? -eq 0 ]; then
      echo "✅ TLS/SNI ativo na porta $port"
      tls_valido="true"
    else
      echo "❌ TLS/SNI falhou na porta $port"
    fi
  done

  # Verificação de redirecionamento com timeout de 5s
  echo ""
  echo "🔁 3) Verificando redirecionamento HTTP/HTTPS..."
  http_redirect=$(curl --max-time 5 -s -I http://$host | grep -i '^Location:')
  https_redirect=$(curl --max-time 5 -s -I https://$host | grep -i '^Location:')
  if [ -n "$http_redirect" ]; then
    echo "⚠️ HTTP redireciona: $http_redirect"
    redir_http="true"
  else
    echo "✅ HTTP sem redirecionamento"
  fi
  if [ -n "$https_redirect" ]; then
    echo "⚠️ HTTPS redireciona: $https_redirect"
    redir_https="true"
  else
    echo "✅ HTTPS sem redirecionamento"
  fi

  # Teste de portas comuns
  echo ""
  echo "🚪 4) Testando portas 80 e 443..."
  for port in 80 443; do
    nc -z -w2 $host $port >/dev/null 2>&1
    if [ $? -eq 0 ]; then
      echo "✅ Porta $port aberta"
      [ $port -eq 80 ] && porta80_aberta="true"
      [ $port -eq 443 ] && porta443_aberta="true"
    else
      echo "❌ Porta $port fechada"
    fi
  done

  # Geolocalização do IP
  echo ""
  echo "🌍 5) Geolocalização IP (via whois)..."
  ip=$(dig +short $host | head -n1)
  if [ -n "$ip" ]; then
    country=$(whois $ip | grep -iE 'country|Country' | head -n1)
    echo "📌 IP: $ip - $country"
  else
    echo "❌ Não foi possível resolver IP"
  fi

  # Armazena se for host ideal
  if [[ "$tls_valido" == "true" && ("$porta443_aberta" == "true" || "$porta80_aberta" == "true") && "$redir_http" == "false" && "$redir_https" == "false" ]]; then
    bons_hosts+=("$host")
  fi

  echo "----------------------------------------------"
  echo ""
done

# Resumo final fixo
echo "✅ Teste finalizado!"
echo ""
echo "🧠 Host ideal para VPN zero-rated:"
echo " - TLS/SNI ativo (porta 443 ou 80)"
echo " - Porta 80 ou 443 aberta"
echo " - Sem redirecionamento HTTP/HTTPS"
echo " - Preferencialmente responde ao ping"
echo " - IP geolocalizado em Angola ou região próxima"
echo " - Testar com chip sem saldo para confirmar se é gratuito"
echo ""

# Exportar bons hosts se existirem
if [ ${#bons_hosts[@]} -gt 0 ]; then
  echo "Deseja exportar os bons hosts para um arquivo? (s/n)"
  read exportar
  if [[ "$exportar" == "s" || "$exportar" == "S" ]]; then
    echo "Salvando em bons_hosts.txt..."
    printf "%s\n" "${bons_hosts[@]}" > bons_hosts.txt
    echo "✅ Arquivo salvo como bons_hosts.txt"
  fi
else
  echo "Nenhum host ideal encontrado para exportar."
fi

echo "🛡️ Powered by VeriHost"