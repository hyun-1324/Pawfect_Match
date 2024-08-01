import { useEffect, useState, useCallback, useRef } from "react";
import { useAuth } from "../../tools/AuthContext";
import { useNavigate, useParams } from "react-router-dom";
import fetchFromEndpoint from "../../tools/fetchFromEndpoint";
import OnlineMark from "../../tools/OnlineMark";

const Chat = () => {
    const { loggedIn, statuses, login, sendJsonMessage, lastJsonMessage } = useAuth();
    const [roomInfo, setRoomInfo] = useState(null); // {id, user_id, unReadMessage}
    const [userInfo, setUserInfo] = useState(null); // {id, dog_name, picture}
    const [chatMessages, setChatMessages] = useState([]); // {can_get_message, id, message, room_id, from_id, to_id, sent_at}
    const [messagesFetched, setMessagesFetched] = useState(false);
    const [lastMessageId, setLastMessageId] = useState(2147483647);
    const [initialLoad, setInitialLoad] = useState(true);

    const [newChatMessage, setNewChatMessage] = useState("");
    const [errorMessage, setErrorMessage] = useState(null);
    const [typing, setTyping] = useState(false);

    const messagesContainerRef = useRef(null);
    const messagesEndRef = useRef(null);
    const typingTimeoutRef = useRef(null);
    const scrollHeightRef = useRef(0);

    const Navigate = useNavigate();
    // get userId from url parameter
    const { id: userId } = useParams();

    useEffect(() => {
        if (!loggedIn) {
            login();
        }
    }, [loggedIn, login]);


    useEffect(() => {
        // fetch userData
        const controller = new AbortController();
        const signal = controller.signal;
        fetchFromEndpoint(`/users/${userId}`, {signal})
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
                setUserInfo(data);
            }
        }).catch((error) => {
            if (error.name === "AbortError") {
            } else {
                setErrorMessage(error.message);
            }
        }).finally(() => {
            sendJsonMessage({event: "get_chat_list"});
        })
        return () => controller.abort();
    }, [Navigate, userId, sendJsonMessage]);

    useEffect(() => {
        // Save room info to state
        if (lastJsonMessage?.event === "get_chat_list" && userInfo && !roomInfo) {
            const room = lastJsonMessage.data?.find((room) => room.user_id === userId);
            setRoomInfo(room);
        }
    }, [lastJsonMessage, userInfo, userId, roomInfo]);
    
    useEffect(() => {
        // Fetch chat messages
        if (roomInfo && chatMessages.length === 0 && !messagesFetched) {
            setChatMessages([]);
            const room_id = String(roomInfo.id);
            sendJsonMessage({ event: "get_messages", data: { room_id: room_id, last_message_id: lastMessageId } });
            setMessagesFetched(true);
        }
    }, [roomInfo, chatMessages.length, messagesFetched, sendJsonMessage, lastMessageId]);
    
    // Save chat messages to state
    useEffect(() => {
        if (lastJsonMessage?.event === "get_messages") {
            const messages = lastJsonMessage.data;
            if (!messages) {
                return;
            }
            // Revert the order of messages
            messages.reverse();
            setChatMessages((prev) => {
                const newMessages = messages.filter(msg => !prev.some(existingMsg => existingMsg.id === msg.id));
                return [...newMessages, ...prev];
            });
            setLastMessageId(messages[0].id);
            const room_id = String(roomInfo.id);
            sendJsonMessage({ event: "check_unread_messages", data: { room_id: room_id, user_id: userId } });
        }
    }, [lastJsonMessage, sendJsonMessage, roomInfo, userId]);
    
    useEffect(() => {
        if (lastJsonMessage?.event === "new_message" && messagesFetched) {
            // save new chat message to state
            const messageData = lastJsonMessage.data;
            setChatMessages((prev) => [...prev, messageData]);
            // send json message to server to clear the new message status
            const room_id = String(messageData.room_id);
            sendJsonMessage({ event: "check_unread_messages", data: { room_id: room_id, user_id: messageData.to_id } });
            setTyping(false);
        }
    }, [lastJsonMessage, sendJsonMessage, messagesFetched]);
    
    useEffect(() => {
        if (lastJsonMessage?.event === "typing") {
            // Clear the previous timeout if it exists
            if (typingTimeoutRef.current) {
                clearTimeout(typingTimeoutRef.current);
            }
            setTyping(true);

            // Set a new timeout to hide the typing message after 3 seconds
            typingTimeoutRef.current = setTimeout(() => {
                setTyping(false);
            }, 3000);
        }
    }, [lastJsonMessage]);

    // If user scrolls up, load more chat messages
    const loadMoreMessages = useCallback(() => {
        const room_id = String(roomInfo.id);
        sendJsonMessage({ event: "get_messages", data: { room_id: room_id, last_message_id: lastMessageId } });
    }, [roomInfo, lastMessageId, sendJsonMessage]);
 

    const handleScroll = useCallback(() => {
        scrollHeightRef.current = messagesContainerRef.current.scrollHeight;
        const scrollTop = messagesContainerRef.current.scrollTop;
        console.log('scrollHeight: ', scrollHeightRef.current);
        console.log('scrollTop: ', scrollTop);
        if (messagesContainerRef.current.scrollTop === 0) {
            console.log('Loading more messages');
            loadMoreMessages();
        }
    }, [loadMoreMessages]);

    useEffect(() => {
        console.log('Initial load: ', initialLoad);
        console.log('Last message: ', lastJsonMessage);
        console.log('Chat messages: ', chatMessages);
        console.log(' ');
        if (initialLoad && chatMessages.length <= 10 && chatMessages.length > 0) {
            scrollToBottom();
            setInitialLoad(false);
        } else if (!initialLoad) {
            
            console.log('Restoring scroll position');
            // Restore scroll position after loading more messages
            messagesContainerRef.current.scrollTop = messagesContainerRef.current.scrollHeight - scrollHeightRef.current;
            
        }
    }, [initialLoad, chatMessages]);

    useEffect(() => {
        const container = messagesContainerRef.current;
        container?.addEventListener('scroll', handleScroll);
        return () => {
            container?.removeEventListener('scroll', handleScroll);
        };
    }, [messagesContainerRef, handleScroll]);
    
    // Scroll to bottom of chat window 
    const scrollToBottom = () => {
        messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
    };


    // Send typing chat message to server
    const handleTyping = useCallback((e) => {
        setNewChatMessage(e.target.value);
        const dataObject = { to_id: userId };
        sendJsonMessage({ event: "typing", data: dataObject });
    }, [userId, sendJsonMessage, setNewChatMessage]);

    // Send chat message to server
    const handleSubmit = useCallback((event) => {
        event.preventDefault();
        newChatMessage.trim();
        if (!newChatMessage) {
            return;
        }
        const dataObject = { 
            to_id: userId, 
            message: newChatMessage,
            sent_at: new Date().toISOString(), 
        };
        sendJsonMessage({ event: "send_message", data: dataObject });
        setNewChatMessage("");
    }, [userId, newChatMessage, sendJsonMessage]);

    const prettifyDate = useCallback((date) => {
        // format date to show date and time. 2024-07-29T07:57:14.251Z => 29/07/2024 07:57
        const dateObj = new Date(date);
        const day = String(dateObj.getDate()).padStart(2, '0');
        const month = String(dateObj.getMonth() + 1).padStart(2, '0');
        const year = dateObj.getFullYear();
        const hours = String(dateObj.getHours()).padStart(2, '0');
        const minutes = String(dateObj.getMinutes()).padStart(2, '0');
        return `${day}/${month}/${year} ${hours}:${minutes}`;
    }, []);

    const generateMessages = useCallback(() => {
        // render chat messages
        return chatMessages.map((message) => (
                <div key={message.id} className={message.to_id === userInfo.id ? "fromMe" : "fromOther"}>
                    <p>{message.message}</p>
                    <p className="date">{prettifyDate(message.sent_at)}</p>
                </div>
            )
        );
    }, [chatMessages, userInfo, prettifyDate]);
        

    return (
        <>
            {userInfo &&
            <div className="chatWindow">
                <div className="chatHeader">
                    <button className="button" onClick={() => Navigate("/chat")}><img src={`${process.env.PUBLIC_URL}/images/back.png`} alt="Back to chat list"></img></button>
                    <img src={
                            userInfo.picture
                            ? userInfo.picture
                            : `${process.env.PUBLIC_URL}/images/defaultProfile.png`
                        } 
                        alt="dog" />
                    <div className="userInfo">
                        <div className="nameAndOnlineMark">
                            <p className="bold">{userInfo.dog_name}</p> 
                            <div className="onlineMarkChat">{OnlineMark(userId, statuses)}</div>
                        </div>
                        {typing && <p> writing...</p>}
                    </div>
                </div>
                {!errorMessage && <div className="messages" ref={messagesContainerRef}>
                    {chatMessages && generateMessages()}
                    <div ref={messagesEndRef} />
                </div>}
                {errorMessage && <p>{errorMessage}</p>}
                <form onSubmit={ (event) => handleSubmit(event)}>
                    <input 
                        type="text" 
                        placeholder="Write your message here..." 
                        value={newChatMessage} 
                        required 
                        maxLength={255} 
                        onChange={(e) => handleTyping(e)} />
                    <button type="submit" className="button"><img src={`${process.env.PUBLIC_URL}/images/send.png`} alt="Send message"></img></button>
                </form>
            </div>}
        </>
    )
}

export default Chat;