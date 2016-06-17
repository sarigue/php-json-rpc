namespace JsonRpcRambler;

use JsonRpcRambler\Exceptions\ConnectionFailureException;
use JsonRpcRambler\Exceptions\ResponseException;

class Client
{
    /**
    * URL of the server
    *
    * @var string
    */
    private url;

    /**
     * If the only argument passed to a function is an array
     * assume it contains named arguments
     *
     * @access public
     * @var boolean
     */
    public namedArguments = true;

    /**
     * HTTP client timeout
     *
     * @access private
     * @var integer
     */
    private timeout;

    /**
     * Username for authentication
     *
     * @access private
     * @var string
     */
    private username;

    /**
     * Password for authentication
     *
     * @access private
     * @var string
     */
    private password;

    /**
     * Do not immediately throw an exception on error. Return it instead.
     *
     * @access public
     * @var boolean
     */
    public suppressErrors = false;

    /**
     * True for a batch request
     *
     * @access public
     * @var boolean
     */
    public isBatch = false;

    /**
     * Batch payload
     *
     * @access public
     * @var array
     */
    public batch = [];

    /**
     * Enable debug output to the php error log
     *
     * @access public
     * @var boolean
     */
    public debug = false;

    /**
     * Default HTTP headers to send to the server
     *
     * @access private
     * @var array
     */
    private headers = [];

    /**
     * Cookies
     *
     * @access private
     * @var array
     */
    private cookies = [];

    /**
     * SSL certificates verification
     *
     * @access public
     * @var boolean
     */
    public sslVerifyPeer = true;

    /**
     * Constructor
     *
     * @access public
     * @param  string    url                 Server URL
     * @param  integer   timeout             HTTP timeout
     * @param  array     headers             Custom HTTP headers
     * @param  bool      suppressErrors     Suppress exceptions
     */
    public function __construct(string url, int timeout = 3, array headers = [], bool suppressErrors = false)
    {
        let this->headers = [
            "User-Agent: JSON-RPC PHP Client",
            "Content-Type: application/json",
            "Accept: application/json",
            "Connection: close"
        ];

        let this->url = url;
        let this->timeout = timeout;
        let this->headers = array_merge(this->headers, headers);
        let this->suppressErrors = !!suppressErrors;
    }

    /**
     * Set authentication parameters
     *
     * @access public
     * @param  string   username   Username
     * @param  string   password   Password
     * @return Client
     */
    public function authentication(username, password)
    {
        let this->username = username;
        let this->password = password;
        return this;
    }

    /**
     * Start a batch request
     *
     * @access public
     * @return Client
     */
    public function batch()
    {
        let this->isBatch = true;
        let this->batch = [];

        return this;
    }

    /**
     * Send a batch request
     *
     * @access public
     * @return array
     */
    public function send()
    {
        let this->isBatch = false;

        return this->parseResponse(
            this->doRequest(this->batch)
        );
    }

    /**
     * Execute a procedure
     *
     * @access public
     * @param  string   procedure   Procedure name
     * @param  array    params      Procedure arguments
     * @return mixed
     */
    public function execute(string procedure, array params = [])
    {
        if (this->isBatch) {
            let this->batch[] = this->prepareRequest(procedure, params);
            return this;
        }

        return this->parseResponse(
            this->doRequest(this->prepareRequest(procedure, params))
        );
    }

    /**
     * Prepare the payload
     *
     * @access public
     * @param  string   procedure   Procedure name
     * @param  array    params      Procedure arguments
     * @return array
     */
    public function prepareRequest(string procedure, array params = [])
    {
        var payload = [
            "jsonrpc": "2.0",
            "method": procedure,
            "id": mt_rand()
        ];

        if (! empty(params)) {
            let payload["params"] = params;
        }
        return payload;
    }

    /**
    * Parse the response and return the procedure result
    *
    * @access public
    * @param  array     payload
    * @return mixed
    */
   public function parseResponse(array payload)
   {
       var results, response;

       if (this->isBatchResponse(payload)) {
           let results = [];
           for response in payload {
               let results[] = this->getResult(response);
           }
           return results;
       }
       return this->getResult(payload);
   }

   /**
   * Throw an exception according the RPC error
   *
   * @param array error
   * @return Exception
   * @throws Exception
   */
  public function handleRpcErrors(array error)
  {
        var e;
        try {
            switch (error["code"]) {
                case -32700:
                    throw new \RuntimeException("Parse error: ". error["message"]);
                case -32600:
                    throw new \RuntimeException("Invalid Request: ". error["message"]);
                case -32601:
                    throw new \BadFunctionCallException("Procedure not found: ". error["message"]);
                case -32602:
                    throw new \InvalidArgumentException("Invalid arguments: ". error["message"]);
                default:
                    throw new Exceptions\ResponseException(
                        error["message"],
                        error["code"],
                        null,
                        isset(error["data"]) ? error["data"] : null
                    );
            }
        } catch \Exception, e {
            if (true === this->suppressErrors) {
                return e;
            }

            throw e;
        }
  }

  /**
   * Throw an exception according the HTTP response
   *
   * @access public
   * @param  array   headers
   * @throws Exceptions\AccessDeniedException
   * @throws Exceptions\ServerErrorException
   */
  public function handleHttpErrors(headers)
  {
        var header, code, exception;
        var exceptions = [
            "401": "\\JsonRpcRambler\\Exceptions\\AccessDeniedException",
            "403": "\\JsonRpcRambler\\Exceptions\\AccessDeniedException",
            "404": "\\JsonRpcRambler\\Exceptions\\ConnectionFailureException",
            "500": "\\JsonRpcRambler\\Exceptions\\ServerErrorException"
        ];

        if (!empty(headers)) {
            for header in headers {
                for code, exception in exceptions {
                    if (strpos(header, "HTTP/1.0 " . code) !== false || strpos(header, "HTTP/1.1 " . code) !== false) {
                        throw new {exception}("Response: " . header);
                    }
                }
            }
        }
  }

  /**
  * Do the HTTP request
  *
  * @access private
  * @param  array payload
  * @return array
  * @throws Exceptions\ConnectionFailureException
  */
 private function doRequest(array payload)
 {
     var stream,
        metadata,
        response_headers,
        response_header,
        pos,
        cookie_defitions,
        cookie_defition,
        cookie_defition_array,
        cookie_name,
        cookie_value,
        response
     ;

     if (filter_var(trim(this->url), FILTER_VALIDATE_URL) === false) {
        throw new \JsonRpcRambler\Exceptions\ConnectionFailureException("Unable to establish a connection");
     }

     let stream = fopen(trim(this->url), 'r', false, this->getContext(payload));

     if (! is_resource(stream)) {
         throw new \JsonRpcRambler\Exceptions\ConnectionFailureException("Unable to establish a connection");
     }
     
     let metadata = stream_get_meta_data(stream);

     // Parse received cookies
     let response_headers = metadata["wrapper_data"];
     for response_header in response_headers {
         let pos = stripos(response_header, "Set-Cookie:");
         if pos === false {
            continue;
         }
         let cookie_defitions = explode(';',  substr(response_header, pos+11));
         for cookie_defition in cookie_defitions {
             let cookie_defition_array = explode('=', cookie_defition);
             if (count(cookie_defition_array) == 2){
                 let cookie_name = trim(cookie_defition_array[0]);
                 let cookie_value = cookie_defition_array[1];
                 let this->cookies[cookie_name] = cookie_value;
             }
         }
     }


     let response = json_decode(stream_get_contents(stream), true);

     if (this->debug) {
         error_log("==> Request: \n". json_encode(payload, JSON_PRETTY_PRINT));
         error_log("==> Response: \n" . json_encode(response, JSON_PRETTY_PRINT));
     }

      this->handleHttpErrors(metadata["wrapper_data"]);
      return is_array(response) ? response : [];
    }

    /**
     * Prepare stream context
     *
     * @access private
     * @param  array   payload
     * @return resource
     */
    private function getContext(array payload)
    {
        var headers, cookie_definitions, cookie_name, cookie_value;
        let headers = this->headers;

        if (! empty(this->username) && ! empty(this->password)) {
            let headers[] = "Authorization: Basic ".base64_encode(this->username.":".this->password);
        }

        if (count(this->cookies)) {
            let cookie_definitions = [];
            for cookie_name, cookie_value in this->cookies {
                let cookie_definitions[] = cookie_name . "=" . cookie_value;
            }
            let headers[] = "Cookie: " . implode("; ", cookie_definitions);
        }

        return stream_context_create([
            "http": [
                "method": "POST",
                "protocol_version": 1.1,
                "timeout": this->timeout,
                "max_redirects": 2,
                "header":  implode("\r\n", headers),
                "content": json_encode(payload),
                "ignore_errors": true
            ],
            "ssl": [
                 "verify_peer": this->sslVerifyPeer,
                 "verify_peer_name": this->sslVerifyPeer
             ]
        ]);
    }

    /**
     * Return true if we have a batch response
     *
     * @access public
     * @param  array    payload
     * @return boolean
     */
    private function isBatchResponse(array payload)
    {
        return array_keys(payload) === range(0, count(payload) - 1);
    }

    /**
     * Get a RPC call result
     *
     * @access private
     * @param  array    payload
     * @return mixed
     */
    private function getResult(array payload)
    {
        if (isset(payload["error"]["code"])) {
            return this->handleRpcErrors(payload["error"]);
        }

        return isset(payload["result"]) ? payload["result"] : null;
    }
}