//
//  main.cpp
//  AudioServer
//
//  Created by loyinglin on 2017/4/1.
//  Copyright © 2017年 loying. All rights reserved.
//

#include <iostream>
#include <unistd.h>
#include <netinet/in.h>
const int port = 51515;

int main (int argc, char * const argv[])
{
    // open the file we are going to stream
    FILE* file = fopen("chenli.mp3", "r");
    if (file == NULL) {
        printf("error file path");
        return 1;
    }
    
    // create listener socket
    int listener_socket;
    listener_socket = socket(AF_INET, SOCK_STREAM, 0);
    if (listener_socket < 0) {
        printf("can't create listener_socket\n");
        return 1;
    }
    
    // bind listener socket
    struct sockaddr_in server_sockaddr;
    server_sockaddr.sin_family = AF_INET;
    server_sockaddr.sin_addr.s_addr = htonl(INADDR_ANY);
    server_sockaddr.sin_port = htons(port);
    if (bind(listener_socket, (struct sockaddr*)&server_sockaddr, sizeof(server_sockaddr)) < 0) {
        printf("can't bind listener_socket\n");
        return 1;
    }
    
    // begin listening for connections
    listen(listener_socket, 4);
    
    // loop for each connection
    while (true) {
        printf("waiting for connection\n");
        
        struct sockaddr_in client_sockaddr;
        socklen_t client_sockaddr_size = sizeof(client_sockaddr);
        int connection_socket = accept(listener_socket, (struct sockaddr*)&client_sockaddr, &client_sockaddr_size);
        if (connection_socket < 0) {
            printf("accept failed\n");
            continue;
        }
        
        printf("connected\n");
        
        off_t totalSent = 0;
        
        // send out the file
        fseek(file, 0, SEEK_SET); // rewind
        while (true) {
            // read from the file
            char buf[32768];
            size_t bytesRead = fread(buf, 1, 32768, file);
            printf("bytesRead %ld\n", bytesRead);
            
            if (bytesRead == 0) {
                printf("done\n");
                break; // eof
            }
            
            // send to the client
            ssize_t bytesSent = send(connection_socket, buf, bytesRead, 0);
            totalSent += bytesSent;
            printf("  bytesSent %ld  totalSent %qd\n", bytesSent, totalSent);
            if (bytesSent < 0) {
                printf("send failed\n");
                break;
            }
        }
        
        close(connection_socket);
    }
    
    // ..never gets here..
    return 0;
}
