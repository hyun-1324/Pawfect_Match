import { useEffect, useState } from "react";
import { useAuth } from "../../tools/AuthContext";
import { useNavigate } from "react-router-dom";
import fetchFromEndpoint from "../../tools/fetchFromEndpoint";
import OnlineMark from "../../tools/OnlineMark";

const ChatList = () => {
    const [ chatList, setChatList ] = useState([]); // []{id, user_id, unReadMessage}
    const [ errorMessage, setErrorMessage ] = useState(null);
    const [ roomInfo, setRoomInfo ] = useState(null); // {id, user_id, unReadMessage, picture, dog_name}

    const { loggedIn, statuses, login, sendJsonMessage, lastJsonMessage, readyState } = useAuth();
    const Navigate = useNavigate();

    // Connect to websocket if not already connected
    useEffect(() => {
        if  (!loggedIn) {
            login();
        }
        
    }, [loggedIn, login]);

    useEffect(() => {
        if (readyState !== 1 && readyState !== 0) {
            Navigate("/login");
        } 
    }, [readyState]);



    // Ask for chat list from server
    useEffect(() => {
        sendJsonMessage({event: "get_chat_list"});
    }, [sendJsonMessage]);

    // Save chat list to state
    useEffect(() => {
        if (lastJsonMessage && lastJsonMessage.event === "get_chat_list") {
            if (lastJsonMessage.data !== null) {
                setChatList(lastJsonMessage.data);
            } else {
                setChatList([]);
            }
        }
    }, [lastJsonMessage]);

    // Fetch user data for each chat
    useEffect(() => {
        const controller = new AbortController();
        const signal = controller.signal;
        const roomInfoMap = new Map();
        if (chatList.length > 0 && !errorMessage) {
            setRoomInfo([]);
            Promise.allSettled(chatList.map((room) => {
                return fetchFromEndpoint(`/users/${room.user_id}`, {signal})
                .then(({data, error}) => {
                    if (error) {
                        if (error.status === 401) {
                            Navigate("/login");
                        } else if (error.status === 404) {
                            Navigate("/notFound");
                        } else {
                            setErrorMessage(error.message);
                        }
                    } else {
                        const roomInfo = {
                            id: room.id,
                            user_id: room.user_id,
                            unReadMessage: room.unReadMessage,
                            picture: data.picture,
                            dog_name: data.dog_name
                        };
                        roomInfoMap.set(room.id, roomInfo);
                    }
                }).catch((error) => {
                    if (error.name === "AbortError") {
                    } else {
                        setErrorMessage(error.message);
                    }
                });
            })).then(() => {
                // Sort roomInfo based on the order of chatList
                const sortedRoomInfo = chatList.map(room => roomInfoMap.get(room.id)).filter(Boolean);
                setRoomInfo(sortedRoomInfo);
            });
        } else {
            setRoomInfo([]);
        }
        return () => controller.abort();
    }, [chatList, errorMessage, Navigate]);
    
    // Make chat list from roomInfo
    const makeChatlist = () => {
        if (roomInfo && chatList.length > 0) {
            return roomInfo.map((room) => (
                <div key={room.id} className="card userCard">
                    <div className="notificationImageContainer">
                        <img src={room.picture ? room.picture : `${process.env.PUBLIC_URL}/images/defaultProfile.png`} 
                            className="cardPicture"
                            alt="Profile picture, click to see profile" 
                            onClick={() => Navigate(`/profileforconnections/${room.user_id}`)} /> 
                        {OnlineMark(room.user_id, statuses)}
                    </div>
                    
                    <div className="nameAndButtons">
                        <p>{room.dog_name}</p>
                        <div className="buttonContainer notificationImageContainer">
                            <button className="button userCardButton" 
                                onClick={() => Navigate(`/chat/${room.user_id}`)}>
                                <img 
                                    src={`${process.env.PUBLIC_URL}/images/chat.png`} 
                                    alt="Open chat with user" />
                            </button>
                            {room.unReadMessage && <div id="chatNotification" className="notificationMark"></div>}
                            
                        </div>
                    </div>
                </div>
            ));
     
        }
        return (
            <div className="card centered">
                <h3>You have no chats.</h3>
            </div>
        );
    };
    
    return (
        <div>
            <h2>Chats</h2>
            {errorMessage && <div className="errorBox">Error: {errorMessage}</div>}
            {!errorMessage && <div className="twoColumnCard">
                <div className="chatList">
                    {makeChatlist()}
                </div>
                <div className="oneColumnCardLeft">
                    <img className="chatImage" src={`${process.env.PUBLIC_URL}/images/chatListDog.png`} alt="dog with paper airplane" />
                </div>
            </div>}

        </div>
    )
}

export default ChatList;