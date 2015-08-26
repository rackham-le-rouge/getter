#!/bin/bash

# preload
. ./context

current_day=`date +%d`
current_month=`date +%m`
current_year=`date +%Y`




# this function is to get a new cookie in case we lost the previous one (expiration or invalidation
# because there is another connexion )
function getanewcookie
{
    lynx -cfg=lynxconfig.config $target -cmd_script=script.lynx
    cookie=`cat cookie.jar | sed -e 's/[a-zA-Z0-9./]*\s//g'`
    echo "New cookie is " $cookie
}

# This function is to ensure that we use good variables
function test_variable
{
    if [ $DEP != "MSC" ]; then
        if [ $DEP != "PLY" ]; then
            echo "Programmation ERROR of the departure"
            exit 1
        fi
    fi

    if [ $DEST != "MSC" ]; then
        if [ $DEST != "PLY" ]; then
            echo "Programmation ERROR of the destination"
            exit 1
        fi
    fi

    if [ $bond_a -ge $bond_b ]; then
        if [ $bond_b -ne 1 ]; then
            echo "Incorrect bond a and b. a should be < b"
            exit 1
        fi
    fi

    if [ $bond_a -eq 1 ]; then
        echo "Incorrect bond a. Connot be 1"
        exit 1
    fi
}

########################################
#          Program starting
########################################


echo -e "Program starting...\n"

# User may want to use the previous-one cookie. Maybee it is still OK
if [ "$1" = "--old-cookie" ]; then
    cookie=`cat cookie.jar | sed -e 's/[a-zA-Z0-9./]*\s//g'`
    echo "Getted cookie is " $cookie
fi


# init. Get back a cookie
if [ "$cookie" = "" ]; then
    if [ -f cookie.jar ]; then
        rm -f cookie.jar
    fi




    echo "Have to get a cookie. Seems to be the starting of the program..."
    getanewcookie
else
    echo -e "Use preprogrammed cookie : "$cookie
fi



# infinite loop. Use cookie, get the string, parse it, validate if availaible or get a new cookie if broken.
# for a random time and after restart the loop again
while [[ $result != "" ]]
do
    # set variables for this turn - one turn, one search
    index_in_the_table=`expr $index_in_the_table + 1`
    if [ $index_in_the_table -eq 5 ]; then
        index_in_the_table=0
    fi

    while [[ ${array_have_to[$index_in_the_table]} -ne 1 ]]
    do
        index_in_the_table=`expr $index_in_the_table + 1`
        if [ $index_in_the_table -eq 5 ]; then
            index_in_the_table=0
        fi
    done


    depart_day=${array_day[$index_in_the_table]}
    depart_month=${array_month[$index_in_the_table]}
    depart_year=${array_year[$index_in_the_table]}
    DEP=${array_departure[$index_in_the_table]}
    DEST=${array_destination[$index_in_the_table]}
    bond_a=${array_bonda[$index_in_the_table]}
    bond_b=${array_bondb[$index_in_the_table]}
    

    test_variable

    result=`curl $target'/ajax_request/mechecker' -H 'Host: '$target_short -H 'User-Agent: Mozilla/5.0 (X11; Linux i686; rv:38.0) Gecko/20100101 Firefox/38.0 Iceweasel/38.2.0' -H 'Accept: application/json, text/javascript, */*; q=0.01' -H 'Accept-Language: fr,fr-FR;q=0.8,en-US;q=0.5,en;q=0.3' --compressed -H 'Content-Type: application/x-www-form-urlencoded; charset=UTF-8' -H 'X-Requested-With: XMLHttpRequest' -H 'Referer: '$target -H 'Cookie: cookie-agreed=2; SESSf5540da1573c6166b93442cf10224b61='$cookie'; has_js=1' -H 'Connection: keep-alive' -H 'Pragma: no-cache' -H 'Cache-Control: no-cache' --data 'od_radio=1&od_depart='$DEP'&od_destination='$DEST'&od_date_depart%5Bdate%5D='$depart_day'%2F'$depart_month'%2F'$depart_year 2>/dev/null`




    # find if the wanted train is checkable or not
    check_status=`echo $result | sed -n 's/^.*\($id":"'$bond_a'".*\)$id\":\"'$bond_b'.*/\1/p' | sed -n 's/.*'$token_status'\":\"\([^"]*\).*/\1/p'`
    obj_num=`echo $result | sed -n 's/^.*\($id":"'$bond_a'".*\)$id\":\"'$bond_b'.*/\1/p' | sed -n 's/.*'$token_num'\":\"\([^"]*\).*/\1/p'`
    obj_id=`echo $result | sed -n 's/^.*\($id":"'$bond_a'".*\)$id\":\"'$bond_b'.*/\1/p' | sed -n 's/.*'$token_id'\":\([^,]*\).*/\1/p'`
    taux_remplissage=`echo $result | sed -n 's/^.*\($id":"'$bond_a'".*\)$id\":\"'$bond_b'.*/\1/p' | sed -n 's/.*'$token_remplissage'\":\([^,]*\).*/\1/p'`

    # comlete line is too much... have to parse it before
    if [ -z $taux_remplissage ]; then
        rm -r cookie.jar
        getanewcookie
    else
        if [ $taux_remplissage -lt 3 ]; then
            # There is an empty place !
            test_variable

            echo -e "\n\ntry to reserve (Date:"$depart_day"/"$depart_month"/"$depart_year" "$DEP" -> "$DEST" num "$obj_num" train id "$obj_id" ): " $check_status

            # take it !
            curl $target'/ajax_request/checkertrain' -H 'Host: '$target_short -H 'User-Agent: Mozilla/5.0 (X11; Linux i686; rv:38.0) Gecko/20100101 Firefox/38.0 Iceweasel/38.2.0' -H 'Accept: application/json, text/javascript, */*; q=0.01' -H 'Accept-Language: en-US,en;q=0.5' --compressed -H 'Content-Type: application/x-www-form-urlencoded; charset=UTF-8' -H 'X-Requested-With: XMLHttpRequest' -H 'Referer: '$target -H 'Cookie: SESSf5540da1573c6166b93442cf10224b61='$cookie'; cookie-agreed=2; has_js=1' -H 'Connection: keep-alive' -H 'Pragma: no-cache' -H 'Cache-Control: no-cache' --data 'idTrain='$obj_id'&od_depart='$DEP'&od_destination='$DEST
            echo -e "\n\n--- TIKET OK - RUNNING DOWN ---\n"

            array_have_to[$index_in_the_table]=0
        fi
    fi

    echo -e "\n\nStatus of the object (Date:"$depart_day"/"$depart_month"/"$depart_year" "$DEP" -> "$DEST" num "$obj_num"): " $check_status

    sleep  $(( ( RANDOM % 40 )  + 21 ))
done

