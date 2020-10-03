package main

import (
	"encoding/json"
	"io/ioutil"
	"fmt"
	"log"
	"os"
	"net/http"
	"strconv"
	"strings"
	"os/exec"
	"bytes"
	"gopkg.in/yaml.v2"
	"github.com/gorilla/mux"
	"github.com/asaskevich/govalidator"
	"github.com/OpenNebula/one/src/oca/go/src/goca"
)

const ShellToUse = "bash"

type Configuration struct {  

	Listen struct {
		Ip		string
		Port	string
	}

	Opennebula struct {
		Endpoint  	string
		Username	string
		Password	string
	}

	Log struct {
		Dir_path  	string
	}
}


func GetConfig() Configuration {  
	file, err := os.Open(os.Args[1])
	if err != nil {
	    log.Fatal(err)
	}
	defer file.Close()
	
	decoder := yaml.NewDecoder(file)
	var cfg Configuration
	err = decoder.Decode(&cfg)
	if err != nil {
	    log.Fatal(err)
	}
	return cfg
}

func logger (strLog string) {
	configuration := GetConfig()
	file, err := os.OpenFile(configuration.Log.Dir_path+"/onemtu.log", os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0666)
    if err != nil {
        log.Fatal(err)
    }

    log.SetOutput(file)

    log.Println(strLog)
}

func execShell(command string) (error, string, string) {
    var stdout bytes.Buffer
    var stderr bytes.Buffer
    cmd := exec.Command(ShellToUse, "-c", command)
    cmd.Stdout = &stdout
    cmd.Stderr = &stderr
    err := cmd.Run()
    logger("Func execShell has been called with "+command+" out "+stdout.String()+" err "+stderr.String())
    return err, stdout.String(), stderr.String()
}

func getOneVMInfoID(vmID int, user string, password string, endpoint string) string {
	client := goca.NewDefaultClient(
		goca.NewConfig(user, password, endpoint),
	)
	controller := goca.NewController(client)

	vm, err := controller.VM(vmID).Info(false)
	if err != nil {
		log.Fatal(err)
	}
	var result = fmt.Sprintf("%+v\n", vm)
	logger("Func getOneVMInfoID has been called with "+string(vmID)+" out "+result)
	return result
}

func getOneVMIDHN(vmHN string) string {
	cmdstr := "sudo -u oneadmin  onevm list --csv | grep -i "+vmHN+" | awk -F, '{print $1}'"
	err, out, errout := execShell(cmdstr)
    if err != nil {
        log.Printf("error: %v\n", err)
        log.Printf("error out: %v\n", errout)
    }
    logger("Func getOneVMIDHN has been called with "+vmHN+" out "+out)
	return strings.TrimRight(out, "\r\n")
}

func updateVMByID(vmID string,netID string, mtu string) string {
	finalResult := "empty"
	configuration := GetConfig()
	found := false
	strHostName := "empty"
	netSearchString := "NETWORK_ID=\""+netID+"\""
	vmIDint, err := strconv.ParseInt(string(vmID), 10, 64)
	if err != nil {
		log.Fatal(err)
	}
	result := getOneVMInfoID(int(vmIDint), configuration.Opennebula.Username, configuration.Opennebula.Password, configuration.Opennebula.Endpoint)
	csvResult := strings.Split(result,",")
	for _, csvEachline := range csvResult {
		if strings.Contains(string(csvEachline), "Hostname:snapp-cn-") {
			spaceResult := strings.Split(csvEachline," ")
			for _, spaceEachline := range spaceResult {
				if strings.Contains(string(spaceEachline), "Hostname:snapp-cn-") {
					strHostName = string(spaceEachline)
					found = true
					break
				}
			}
		} else {
			continue
		}
	} 
	if found {
		hostName := "empty"
		strHostNameTemp := strings.Split(strHostName,":")
		for _, strHostNameTempEach := range strHostNameTemp {
			if strings.Contains(string(strHostNameTempEach), "snapp-cn-") {
				hostName = string(strHostNameTempEach)
				break
			}
		}
		nicExists := false 
		nicNotFound := true 
		storageNicID := "-1"
		for _, csvEachline := range csvResult {

			if strings.Contains(string(csvEachline), netSearchString) {
				nicExists = true
			}
			if nicExists && strings.Contains(string(csvEachline), "NIC_ID=") && nicNotFound {
				nicTempString := strings.Split(csvEachline,"=")
				for _, csvNicTempString := range nicTempString {
					if strings.Contains(string(csvNicTempString), "NIC_ID"){
						continue
					}else{
						storageNicID = strings.Trim(csvNicTempString, "\"")
						nicNotFound = false
					}
				}
			}
		}
		if nicExists {
			nicNamestr := "one-"+vmID+"-"+storageNicID
			getRequest := "http://"+hostName+":"+configuration.Listen.Port+"/nicupdate/"+nicNamestr+"/mtu/"+mtu
    		resp, err := http.Get(getRequest)
    		if err != nil {
				log.Fatal(err)
			}
			body, err := ioutil.ReadAll(resp.Body)
    		finalResult = string(body)
    		logger("Endpoint /vmupdate/"+vmID+"/"+netID+"/mtu/"+mtu+" called and response was "+"done")
		} else {
			finalResult = "Host does not have Storage interface"
			logger("Endpoint /vmupdate/"+vmID+"/"+netID+"/mtu/"+mtu+" called and response was "+"Host does not have Storage interface")
		}
	} else {
		finalResult = "Host with ID Not Found"
		logger("Endpoint /vmupdate/"+vmID+"/mtu/"+mtu+"/"+netID+" called and response was "+"Host with ID Not Found")
	}
	logger("Func updateVMByID has been called with "+vmID+" mtu "+mtu+"/"+netID+" out "+finalResult)
	return finalResult
}

func updateVMByHN(vmHN string,netID string, mtu string) string {
	finalResult := "empty"
	vmID := getOneVMIDHN(vmHN)
	finalResult = updateVMByID(vmID,netID,mtu)
	logger("Func updateVMByHN has been called with "+vmID+" mtu "+mtu+"/"+netID+" out "+finalResult)
	return finalResult
}

func updateMtu(w http.ResponseWriter, r *http.Request) {
	nicNamestr := mux.Vars(r)["nicName"]
	mtu := mux.Vars(r)["mtu"]
	cmdstr := "ip link set "+nicNamestr+" mtu "+mtu
	err, out, errout := execShell(cmdstr)
    if err != nil {
        log.Printf("error: %v\n", err)
    }
    logger("Func updateMtu has been called with "+nicNamestr+" mtu "+mtu)
    logger("Endpoint /nicupdate/"+nicNamestr+"/mtu/"+mtu+" called with stdout "+out+" and stderr "+errout)
}

func updateVM(w http.ResponseWriter, r *http.Request) {
	result := "empty"
	vmID := mux.Vars(r)["vmID"]
	netID := mux.Vars(r)["netID"]
	mtu := mux.Vars(r)["mtu"]
	if govalidator.IsInt(string(vmID)) {
		result = updateVMByID(vmID,netID,mtu)
	} else {
		result = updateVMByHN(vmID,netID,mtu)
	}
	json.NewEncoder(w).Encode(result)
    logger("Func updateVM has been called with "+vmID+" mtu "+mtu)
}

func main() {
	cfg := GetConfig()
	logger("Service start")
	listenStr := cfg.Listen.Ip+":"+cfg.Listen.Port
	router := mux.NewRouter().StrictSlash(true)
	router.HandleFunc("/vmupdate/{vmID}/{netID}/mtu/{mtu}", updateVM).Methods("GET")
	router.HandleFunc("/nicupdate/{nicName}/mtu/{mtu}", updateMtu).Methods("GET")
	log.Fatal(http.ListenAndServe(listenStr, router))
}