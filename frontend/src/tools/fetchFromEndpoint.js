const fetchFromEndpoint = async (url, {signal}) => {
    const response = await fetch(url, { signal: signal });
    if (!response.ok) {
    // Handle HTTP errors
    let errorResponse;
    const error = new Error();
    try {
        errorResponse = await response.json();
    } catch (jsonError) {
      error.message = "Failed to reach server";
      error.status = 500;
      return { data: null, error };
    } 
    error.status = response.status; // Include the status code
    error.message = errorResponse.Message || "Unknown error"; // Include the error message; 
    return { data: null, error };
    }
    const data = await response.json();
    return { data, error: null };
    
  };

  export default fetchFromEndpoint;