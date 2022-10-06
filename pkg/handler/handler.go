package handler

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"

	"github.com/open-policy-agent/frameworks/constraint/pkg/externaldata"
	"github.com/open-policy-agent/gatekeeper-external-data-provider/pkg/utils"
	"k8s.io/klog/v2"
)

func Handler(w http.ResponseWriter, req *http.Request) {
	// only accept POST requests
	if req.Method != http.MethodPost {
		utils.SendResponse(nil, "only POST is allowed", w)
		return
	}

	// read request body
	requestBody, err := io.ReadAll(req.Body)
	if err != nil {
		utils.SendResponse(nil, fmt.Sprintf("unable to read request body: %v", err), w)
		return
	}

	klog.InfoS("received request", "body", requestBody)

	// parse request body
	var providerRequest externaldata.ProviderRequest
	err = json.Unmarshal(requestBody, &providerRequest)
	if err != nil {
		utils.SendResponse(nil, fmt.Sprintf("unable to unmarshal request body: %v", err), w)
		return
	}

	results := make([]externaldata.Item, 0)
	// iterate over all keys
	for _, key := range providerRequest.Request.Keys {
		// Providers should add a caching mechanism to avoid extra calls to external data sources.

		// following checks are for testing purposes only
		// check if key contains "_systemError" to trigger a system error
		if strings.HasSuffix(key, "_systemError") {
			utils.SendResponse(nil, "testing system error", w)
			return
		}

		// check if key contains "error_" to trigger an error
		if strings.HasPrefix(key, "error_") {
			results = append(results, externaldata.Item{
				Key:   key,
				Error: key + "_invalid",
			})
		} else if !strings.HasSuffix(key, "_valid") {
			// valid key will have "_valid" appended as return value
			results = append(results, externaldata.Item{
				Key:   key,
				Value: key + "_valid",
			})
		}
	}
	utils.SendResponse(&results, "", w)
}
