#!/bin/bash

show_help() {
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  -p, --port [PORT]       Display all active ports and services or details for a specific port"
  echo "  -d, --docker [CONTAINER] List all Docker images and containers or details for a specific container"
  echo "  -n, --nginx [DOMAIN]    Display all Nginx domains and their ports or details for a specific domain"
  echo "  -u, --users [USERNAME]  List all users and their last login times or details for a specific user"
  echo "  -t, --time [START] [END] Display activities within a specified time range"
  echo "  -h, --help              Display this help message"
}

list_ports() {
  echo -e "USER\tPORT\tSERVICE"

  # For TCP ports
  sudo lsof -nP -iTCP -sTCP:LISTEN | awk 'NR>1 {split($9, a, ":"); print $3 "\t" a[length(a)] "\t" $1}' | column -t

  # For UDP ports
  sudo lsof -nP -iUDP | awk 'NR>1 {split($9, a, ":"); print $3 "\t" a[length(a)] "\t" $1}' | column -t
}

port_details() {
  local port=$1

  echo -e "USER\tPORT\tSERVICE"

  # For TCP ports
  sudo lsof -nP -iTCP -sTCP:LISTEN | awk -v port="$port" '$9 ~ ":" port "$" {split($9, a, ":"); print $3 "\t" a[length(a)] "\t" $1}' | column -t

  # For UDP ports
  sudo lsof -nP -iUDP | awk -v port="$port" '$9 ~ ":" port "$" {split($9, a, ":"); print $3 "\t" a[length(a)] "\t" $1}' | column -t
}

list_docker() {
  echo "Docker Images:"
  echo
  printf "| %-25s | %-30s | %-25s | %-25s |\n" "REPOSITORY" "TAG" "IMAGE ID" "SIZE"
  echo "-----------------------------------------------------------------------------------------------------------------------"
  docker images --format "{{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}" | while IFS=$'\t' read -r repo tag id size; do
    printf "| %-25s | %-30s | %-25s | %-25s |\n" "$repo" "$tag" "$id" "$size"
  done
  echo "-----------------------------------------------------------------------------------------------------------------------"
  echo ""

  echo "Docker Containers:"
  echo
  printf "| %-25s | %-30s | %-25s | %-25s |\n" "NAMES" "IMAGE" "STATUS" "PORTS"
  echo "-----------------------------------------------------------------------------------------------------------------------"
  docker ps -a --format "{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" | while IFS=$'\t' read -r name image status ports; do
    printf "| %-25s | %-30s | %-25s | %-25s |\n" "$name" "$image" "$status" "$ports"
  done
  echo "-----------------------------------------------------------------------------------------------------------------------"
}

docker_details() {
  CONTAINER=$1
  docker inspect "$CONTAINER"
}


list_nginx() {
  echo -e "Server domain\t\t\t\tProxy\t\t\t\tConfiguration File"

  # Set locale to avoid warnings
  export LC_ALL=C
  export LANG=C

  # Process each file in the sites-enabled directory
  for conf_file in /etc/nginx/sites-enabled/*; do
    # Initialize variables for each file
    local domain=""
    local proxy=""

    while IFS= read -r line; do
      # Remove carriage return characters if present
      line=$(echo "$line" | tr -d '\r')

      # Skip commented and empty lines
      if [[ -z "${line//[$'\t'[:space:]]/}" || "$line" =~ ^[[:space:]]*# ]]; then
        continue
      fi

      # Check if line contains server_name
      if echo "$line" | grep -q '\bserver_name\b'; then
        domain=$(echo "$line" | awk -F'server_name' '{print $2}' | awk -F';' '{print $1}' | sed 's/,/, /g' | xargs)

        # Special case: If server_name is "_", set domain and proxy to default values
        if [[ "$domain" == "_" ]]; then
          domain="localhost"
          proxy="http://localhost:80"
          # Skip the next processing for proxy since it is a special case
          continue
        fi
      fi

      # Extract proxy pass URL from proxy_pass directive
      if echo "$line" | grep -q '\bproxy_pass\b'; then
        proxy=$(echo "$line" | awk -F'proxy_pass' '{print $2}' | awk -F';' '{print $1}' | xargs)
      fi
    done < "$conf_file"

    # Print the extracted information if both domain and proxy are not empty
    if [[ -n "$domain" && -n "$proxy" ]]; then
      printf "%-30s\t%-35s\t%s\n" "$domain" "$proxy" "$conf_file"
    fi
  done
}



nginx_details() {
  DOMAIN=$1
  grep -R "server_name $DOMAIN" /etc/nginx/sites-enabled/* | awk '{print $1 "\t" $3 "\t" $5}' | column -t
}

list_users() {
  echo -e "USER\t\tLAST LOGIN"
  lastlog | awk 'NR>1 {
    last_login = ($4 == "in**") ? "-" : $4 " " $5 " " $6
    printf "%-20s %s\n", $1, last_login
  }' | column -t
}

user_details() {
  USER=$1
  echo -e "USER\t\tLAST LOGIN"
  lastlog | grep "^$USER" | awk '{
    last_login = ($4 == "in**") ? "-" : $4 " " $5 " " $6
    printf "%-20s %s\n", $1, last_login
  }' | column -t
}

list_time_range() {
  START=$1
  END=$2
  if [ -z "$END" ]; then
    END=$(date +"%Y-%m-%d")
  fi
  echo "Showing activities from $START to $END"
  last -F | awk -v start="$START" -v end="$END" '{if ($5 >= start && $5 <= end) print $0}' | column -t
}

# list_time_range() {
#   START=$1
#   END=$2

#   # Check if END is empty and set to current date if so
#   if [ -z "$END" ]; then
#     END=$(date +"%Y-%m-%d")
#   fi

#   echo "Showing activities from $START to $END"

#   # Determine the OS and convert dates to seconds since epoch
#   if [[ "$(uname)" == "Darwin" ]]; then
#     # macOS
#     start_sec=$(date -j -f "%Y-%m-%d" "$START" +%s 2>/dev/null)
#     end_sec=$(date -j -f "%Y-%m-%d" "$END" +%s 2>/dev/null)
#   else
#     # Linux
#     start_sec=$(date -d "$START" +%s 2>/dev/null)
#     end_sec=$(date -d "$END" +%s 2>/dev/null)
#   fi

#   # Check if date conversion was successful
#   if [ -z "$start_sec" ] || [ -z "$end_sec" ]; then
#     echo "Error: Invalid date format."
#     return 1
#   fi

#   last | while read line; do
#     # Extract date from the line (assuming format Jul 25)
#     month=$(echo "$line" | awk '{print $5}')
#     day=$(echo "$line" | awk '{print $6}')
#     year=$(date +"%Y")

#     # Handle end-of-year transition
#     if [ "$month" == "Jan" ] && [ "$(date +%m)" == "12" ]; then
#       year=$((year - 1))
#     fi

#     date_str="$year-$month-$day"

#     if [[ "$(uname)" == "Darwin" ]]; then
#       # macOS
#       date_sec=$(date -j -f "%Y-%b-%d" "$date_str" +%s 2>/dev/null)
#     else
#       # Linux
#       date_sec=$(date -d "$date_str" +%s 2>/dev/null)
#     fi

#     # Check if date conversion was successful
#     # if [ -z "$date_sec" ]; then
#     #   continue
#     # fi

#     if [ "$date_sec" -ge "$start_sec" ] && [ "$date_sec" -le "$end_sec" ]; then
#       echo "$line"
#     fi
#   done | column -t
# }


# Process command-line arguments
case $1 in
  -p|--port)
    if [ -n "$2" ]; then
      port_details "$2"
    else
      list_ports
    fi
    ;;
  -d|--docker)
    if [ -n "$2" ]; then
      docker_details "$2"
    else
      list_docker
    fi
    ;;
  -n|--nginx)
    if [ -n "$2" ]; then
      nginx_details "$2"
    else
      list_nginx
    fi
    ;;
  -u|--users)
    if [ -n "$2" ]; then
      user_details "$2"
    else
      list_users
    fi
    ;;
  -t|--time)
    list_time_range "$2" "$3"
    ;;
  -h|--help)
    show_help
    ;;
  *)
    echo "Unknown option: $1"
    show_help
    ;;
esac

# rsync -avz /home/azeez/Documents/projects/stage_5-1_task hayzeddev@192.168.1.165:/Users/hayzeddev/Documents/hng-11-devops