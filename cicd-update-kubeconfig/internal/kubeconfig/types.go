package kubeconfig

// Config represents a Kubernetes kubeconfig file structure
type Config struct {
	APIVersion     string         `yaml:"apiVersion"`
	Kind           string         `yaml:"kind"`
	Clusters       []NamedCluster `yaml:"clusters"`
	Contexts       []NamedContext `yaml:"contexts"`
	Users          []NamedUser    `yaml:"users"`
	CurrentContext string         `yaml:"current-context"`
}

// NamedCluster represents a cluster entry in kubeconfig
type NamedCluster struct {
	Name    string  `yaml:"name"`
	Cluster Cluster `yaml:"cluster"`
}

// Cluster contains cluster connection details
type Cluster struct {
	Server                   string `yaml:"server"`
	CertificateAuthorityData string `yaml:"certificate-authority-data,omitempty"`
	CertificateAuthority     string `yaml:"certificate-authority,omitempty"`
}

// NamedContext represents a context entry in kubeconfig
type NamedContext struct {
	Name    string  `yaml:"name"`
	Context Context `yaml:"context"`
}

// Context contains context details
type Context struct {
	Cluster   string `yaml:"cluster"`
	User      string `yaml:"user"`
	Namespace string `yaml:"namespace,omitempty"`
}

// NamedUser represents a user entry in kubeconfig
type NamedUser struct {
	Name string `yaml:"name"`
	User User   `yaml:"user"`
}

// User contains user authentication details
type User struct {
	ClientCertificateData string `yaml:"client-certificate-data,omitempty"`
	ClientKeyData         string `yaml:"client-key-data,omitempty"`
	ClientCertificate     string `yaml:"client-certificate,omitempty"`
	ClientKey             string `yaml:"client-key,omitempty"`
	Token                 string `yaml:"token,omitempty"`
	Username              string `yaml:"username,omitempty"`
	Password              string `yaml:"password,omitempty"`
}
