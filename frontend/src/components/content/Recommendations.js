import { SocketContext } from "../../socketContext";
import { useContext, useState } from "react";
import { useFetch } from "../../tools/useFetch";

const Recommendations = () => {
    const socket = useContext(SocketContext);
    const [isPending, setIsPending] = useState(true);
    const [error, setError] = useState(null);
    // Check if location should be updated
    // Fetch recommendations from the server
    
    return (
        <div className="recommendations">
            <h2>Recommendations</h2>
        </div>
    

    );
    }

export default Recommendations;
