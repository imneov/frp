package kubernetes

import (
	"fmt"
	"net/url"
	"strconv"
	"strings"
)

type ServiceInfo struct {
	Protocol  string
	Name      string
	Namespace string
	Cluster   string
	Port      int64
	Type      string // "pod" or "svc"
	IP        string
	Metadata  map[string]string
}

// 构造 FRP 服务名称
func GenerateServiceName(info ServiceInfo) (string, error) {
	if info.Protocol == "" || info.Name == "" || info.Namespace == "" || info.Cluster == "" || info.Port <= 0 {
		return "", fmt.Errorf("missing required field")
	}

	// 主体部分
	host := fmt.Sprintf("%s.%s.%s:%d", info.Name, info.Namespace, info.Cluster, info.Port)
	path := ""
	if info.Type != "" && info.IP != "" {
		path = fmt.Sprintf("/%s/%s", info.Type, info.IP)
	} else if info.Type != "" {
		path = fmt.Sprintf("/%s", info.Type)
	}

	// 查询参数
	query := url.Values{}
	for k, v := range info.Metadata {
		query.Set(k, v)
	}

	// 拼接 URI
	serviceURI := fmt.Sprintf("%s://%s%s", info.Protocol, host, path)
	if q := query.Encode(); q != "" {
		serviceURI += "?" + q
	}
	return serviceURI, nil
}

// 解析 FRP 服务名称
func ParseServiceName(uri string) (*ServiceInfo, error) {
	u, err := url.Parse(uri)
	if err != nil {
		return nil, err
	}

	parts := strings.Split(u.Hostname(), ".")
	if len(parts) != 3 {
		return nil, fmt.Errorf("invalid hostname: %s", u.Hostname())
	}

	name := parts[0]
	namespace := parts[1]
	cluster := parts[2]
	port, err := strconv.ParseInt(u.Port(), 10, 64)
	if err != nil {
		return nil, fmt.Errorf("invalid port %q: %w", u.Port(), err)
	}

	// 路径部分
	pathParts := strings.Split(strings.Trim(u.Path, "/"), "/")
	infoType, ip := "", ""
	if len(pathParts) >= 1 {
		infoType = pathParts[0]
	}
	if len(pathParts) >= 2 {
		ip = pathParts[1]
	}

	// 查询参数
	meta := map[string]string{}
	for k, v := range u.Query() {
		meta[k] = v[0]
	}

	return &ServiceInfo{
		Protocol:  u.Scheme,
		Name:      name,
		Namespace: namespace,
		Cluster:   cluster,
		Port:      port,
		Type:      infoType,
		IP:        ip,
		Metadata:  meta,
	}, nil
}
