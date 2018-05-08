package main

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
)

// InstanceMetadata from Azure Instance Metadata Service
type InstanceMetadata struct {
	ComputeMetadata ComputeMetadata `json:"compute"`
	NetworkMetadata NetworkMetadata `json:"network"`
}

// ComputeMetadata from Azure Instance Metadata Service
type ComputeMetadata struct {
	Location             string `json:"location"`
	Name                 string `json:"name"`
	Offer                string `json:"offer"`
	OSType               string `json:"osType"`
	PlacementGroupID     string `json:"placementGroupId"`
	PlatformFaultDomain  string `json:"platformFaultDomain"`
	PlatformUpdateDomain string `json:"platformUpdateDomain"`
	Publisher            string `json:"publisher"`
	ResourceGroupName    string `json:"resourceGroupName"`
	SKU                  string `json:"sku"`
	SubscriptionID       string `json:"subscriptionId"`
	Tags                 string `json:"tags"`
	Version              string `json:"version"`
	VMID                 string `json:"vmId"`
	VMScaleSetName       string `json:"vmScaleSetName"`
	VMSize               string `json:"vmSize"`
	Zone                 string `json:"zone"`
}

// NetworkMetadata contains metadata about an instance's network
type NetworkMetadata struct {
	Interface []NetworkInterface `json:"interface"`
}

// NetworkInterface represents an instances network interface
type NetworkInterface struct {
	IPV4 NetworkData `json:"ipv4"`
	IPV6 NetworkData `json:"ipv6"`
	MAC  string      `json:"macAddress"`
}

// NetworkData contains IP information for a network
type NetworkData struct {
	IPAddress []IPAddress `json:"ipAddress"`
	Subnet    []Subnet    `json:"subnet"`
}

// IPAddress represents IP address information
type IPAddress struct {
	PrivateIP string `json:"privateIPAddress"`
	PublicIP  string `json:"publicIPAddress"`
}

// Subnet represents subnet information
type Subnet struct {
	Address string `json:"address"`
	Prefix  string `json:"prefix"`
}

// RespMetaData from ComputeMetadata
type RespMetaData struct {
	Name string `json:"name"`
	Zone string `json:"zone"`
}

func handler(w http.ResponseWriter, r *http.Request) {
	client := &http.Client{}
	metadataURL := "http://169.254.169.254/metadata/instance"
	format := "json"
	apiVersion := "2017-12-01"

	req, err := http.NewRequest("GET", metadataURL, nil)
	if err != nil {
		log.Fatal(err)
	}
	req.Header.Add("Metadata", "True")

	q := req.URL.Query()
	q.Add("format", format)
	q.Add("api-version", apiVersion)
	req.URL.RawQuery = q.Encode()

	resp, err := client.Do(req)
	if err != nil {
		log.Fatal(err)
	}
	defer resp.Body.Close()

	respBody, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		log.Fatal(err)
	}

	instanceMetadata := InstanceMetadata{}
	err = json.Unmarshal(respBody, &instanceMetadata)
	if err != nil {
		log.Fatal(err)
	}

	fmt.Fprintf(w, "[VM Name]:%s   [Zone]:%s   [PrivateIP]:%s \n", instanceMetadata.ComputeMetadata.Name, instanceMetadata.ComputeMetadata.Zone, instanceMetadata.NetworkMetadata.Interface[0].IPV4.IPAddress[0].PrivateIP)
}

func main() {
	http.HandleFunc("/", handler)
	http.ListenAndServe(":80", nil)
}
