#!/bin/bash
trap reset EXIT

twidth=$(tput cols)
theight=$(tput lines)

newscreen() { #clear screen and draw border lines
clear
tput cup $(($theight - 1)) 0; echo -n "$(printf "\033[42m%*s\033[0m" $(($twidth - 1)) "")"
tput cup 0 0; echo "$(printf "\033[42m%*s\033[0m" $twidth "")"
for i in $(seq 0 $(($theight - 1)) ); do
  tput cup $i $twidth; echo -ne "\e[42m \e[0m"
  tput cup $(($theight - $i)) 0; echo -ne "\e[42m \e[0m"
done

#for i in $(seq $(($theight - 1)) -1 1); do tput cup $i 0; echo -ne "\e[42m \e[0m"; done
}

gamemenu() { # game menu
  unselected() {
    item=${menuitems[$1]}
    tput cup $(($theight / 2 + $1)) $(($twidth / 2 - $((${#item} / 2)) ))
    echo $item
  }
  selected() {
    item=${menuitems[$1]}
    tput cup $(($theight / 2 + $1)) $(($twidth / 2 - $((${#item} / 2)) ))
    echo -e "\033[32m$item\033[0m"
  }
whichselected=0

if [[ $level -eq -12 ]]; then
  menuitems=("new game" "quit")
else
  menuitems=("continue game" "new game" "quit")
fi

for i in $(seq 0 $((${#menuitems[@]} - 1)) ); do
  unselected $i
done
selected $whichselected

while true; do
  move=0
  read -s -n 1 key
  case $key in
    $'\x1b') read -s -n 2 subkey
      case $subkey in
        [A) move=-1;;
        [B) move=1;;
      esac
      ;;
    w) move=-1;;
    s) move=1;;
    "") break;;
    q) exit;;
  esac
  if [ $move -ne 0 ]; then
    unselected $whichselected
    whichselected=$(($whichselected + $move))
    if [ $whichselected -lt 0 ]; then whichselected=$((${#menuitems[@]} - 1)); fi
    if [ $whichselected -gt $((${#menuitems[@]} - 1)) ]; then whichselected=0; fi
    selected $whichselected
  fi
done
}

newlevel() {
  # random adversary positions
  for i in $(seq 1 $level); do
    advx[$i]=$(( RANDOM % $(($twidth - 2)) + 1 ))
    advy[$i]=$(( RANDOM % $(($theight - 2)) + 1 ))
  done

  # random positions of player and goal
  userx=$(( RANDOM % $(($twidth - 2)) + 1 ))
  usery=$(( RANDOM % $(($theight - 2)) + 1 ))
  goalx=$(( RANDOM % $(($twidth - 2)) + 1 ))
  goaly=$(( RANDOM % $(($theight - 2)) + 1 ))
  echo -ne "\033[?25l"
}

drawgame() {
  # draw player, adversaries, and goal
  newscreen
  tput cup $goaly $goalx
  echo -ne "O"
  tput cup $usery $userx
  echo -ne "\e[36m+\e[0m"
  for i in $(seq 1 $level); do
    tput cup ${advy[$i]} ${advx[$i]}
    echo -ne "\e[32mX\e[0m"
  done
}

game() {
until [ $won -eq -1 ]; do
drawgame
  # level loop
  moves=0
  won=0
  stty -icanon -echo
  while [ $won -eq 0 ]; do
    move=0
    read -s -n 1 key
    case $key in
      $'\x1b') read -s -n 2 subkey
        case $subkey in
          [A) move=1;;
          [B) move=3;;
          [C) move=2;;
          [D) move=4;;
        esac
        ;;
      w|W) move=1;;
      a|A) move=4;;
      s|S) move=3;;
      d|D) move=2;;
      q) break 3;;
    esac
    tput cup $usery $userx
    case $move in
      1) echo -n " "; [ $usery -gt 1 ] && usery=$(( $usery - 1 ));;
      2) echo -n " "; [ $userx -lt $(($twidth - 2)) ] && userx=$(( $userx + 1 ));;
      3) echo -n " "; [ $usery -lt $(($theight - 2)) ] && usery=$(( $usery + 1 ));;
      4) echo -n " "; [ $userx -gt 1 ] && userx=$(( $userx - 1 ));;
    esac
    tput cup $usery $userx
    echo -ne "\e[36m+\e[0m"
    if [ $userx -eq $goalx ] && [ $usery -eq $goaly ]; then
      won=1
      break
    fi

    # adversaries move
    if [ move != 0 ]; then
      moves=$(( $moves + 1 ))
      if (( $moves % 2 == 0 )); then
        for i in $(seq 1 $level); do
          tput cup ${advy[$i]} ${advx[$i]}
          echo -ne " "
          if [ ${advx[$i]} -gt $userx ]; then
            advx[$i]=$(( ${advx[$i]} - 1 ))
          fi
          if [ $userx -gt ${advx[$i]} ]; then
            advx[$i]=$(( ${advx[$i]} + 1 ))
          fi
          if [ ${advy[$i]} -gt $usery ]; then
            advy[$i]=$(( ${advy[$i]} - 1 ))
          fi
          if [ $usery -gt ${advy[$i]} ]; then
            advy[$i]=$(( ${advy[$i]} + 1 ))
          fi
          #advx[$i]=$((userx - advx[$i]))
          tput cup ${advy[$i]} ${advx[$i]}
          echo -ne "\e[32mX\e[0m"
          if [ ${advy[$i]} -eq $usery ] && [ ${advx[$i]} -eq $userx ]; then
            won=-1
          fi
        done
      fi
    fi
    tput cup $goaly $goalx
    echo -ne "O"
  done

  # end of level
  tput cup $(($theight - 2)) 1
  if [ $won -eq -1 ]; then
    echo "level $(($level - 1)) lost"
    level=-12
    sleep 1
  else
    level=$(( level + 1 ))
    echo "level $(($level - 1)) won - starting level $level"
    sleep 1
    newlevel
  fi
done
}


echo -e "\033[?25l"
level=-12
while true; do
  newscreen
  gamemenu
  if [[ $level -eq -12 ]]; then
    whichselected=$(($whichselected + 1))
  fi
  case $whichselected in
    0) game;;
    1) echo 0; level=0; won=0; newlevel; game;;
    2) exit;;
    3) echo 3;;
    4) echo 4;;
  esac
done
