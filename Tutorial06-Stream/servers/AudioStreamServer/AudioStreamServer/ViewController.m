//
//  ViewController.m
//  AudioStreamServer
//
//  Created by 林伟池 on 2017/4/1.
//  Copyright © 2017年 loying. All rights reserved.
//

#import "ViewController.h"
#include <unistd.h>
#include <netinet/in.h>

@implementation ViewController
const int port = 51515;

- (void)viewDidLoad {
    [super viewDidLoad];

    // Do any additional setup after loading the view.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self startServer];
    });
}



/**
 如果尝试send到一个已关闭的 socket上两次，就会出现此信号，也就是用协议TCP的socket编程，服务器是不能知道客户机什么时候已经关闭了socket，导致还在向该已关 闭的socket上send，导致SIGPIPE。
 而系统默认产生SIGPIPE信号的措施是关闭进程，所以出现了服务器也退出。
 */
- (int)startServer {
    FILE* file = fopen([[[NSBundle mainBundle] pathForResource:@"chenli" ofType:@"mp3"] UTF8String], "r");
    if (file == NULL) {
        printf("error file path\n");
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
}


- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}


@end
