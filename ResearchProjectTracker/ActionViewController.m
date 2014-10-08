//
//  ActionViewController.m
//  ResearchProjectTracker
//
//  Created by Lucas Damian Napoli on 08/10/14.
//  Copyright (c) 2014 microsoft. All rights reserved.
//
#import "ProjectTableExtensionViewCell.h"
#import "office365-base-sdk/Credentials.h"
#import <office365-base-sdk/LoginClient.h>
#import <office365-base-sdk/OAuthentication.h>
#import "ProjectClientEx.h"
#import <office365-lists-sdk/ListItem.h>
#import <office365-lists-sdk/ListEntity.h>
#import <QuartzCore/QuartzCore.h>
#import "ActionViewController.h"
#import <MobileCoreServices/MobileCoreServices.h>

@interface ActionViewController ()

@property(strong,nonatomic) IBOutlet UIImageView *imageView;

@end

@implementation ActionViewController

ADAuthenticationContext* authContext;
NSString* authority;
NSString* redirectUriString;
NSString* resourceId;
NSString* clientId;
Credentials* credentials;
NSString* token;
ListItem* currentEntity;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    authority = [NSString alloc];
    resourceId = [NSString alloc];
    clientId = [NSString alloc];
    redirectUriString = [NSString alloc];
    authority = @"https://login.windows.net/common";
    resourceId = @"https://foxintergen.sharepoint.com";
    clientId = @"13b04d26-95fc-4fb4-a67e-c850e07822a8";
    redirectUriString = @"http://android/complete";
    token = [NSString alloc];
    
    for (NSExtensionItem *item in self.extensionContext.inputItems) {
        for (NSItemProvider *itemProvider in item.attachments) {
            if ([itemProvider hasItemConformingToTypeIdentifier:(NSString *)kUTTypeURL]) {
                
                __weak ActionViewController *sself = self;
                
                [itemProvider loadItemForTypeIdentifier: (NSString *) kUTTypeURL
                                                options: 0
                                      completionHandler: ^(id<NSSecureCoding> item, NSError *error) {
                                          
                                          if (item != nil) {
                                              NSURL *url = item;
                                              sself.sharedUrl = [url absoluteString];
                                              
                                              [sself.urlTxt performSelectorOnMainThread : @ selector(setText : ) withObject:[url absoluteString] waitUntilDone:YES];
                                    
                                          }
                                          
                                      }];
                
            }
        }
    }
    
    [self performLogin:FALSE];
}

- (void) performLogin : (BOOL) clearCache{
    
    LoginClient *client = [[LoginClient alloc] initWithParameters:clientId:redirectUriString:resourceId:authority];
    [client login:clearCache completionHandler:^(NSString *t, NSError *e) {
        if(e == nil)
        {
            token = t;
            
            [self loadData];
            
            //[self.navigationController pushViewController:controller animated:YES];
        }
        else
        {
            //NSString *errorMessage = [@"Login failed. Reason: " stringByAppendingString: e.description];
            //UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:errorMessage delegate:self cancelButtonTitle:@"Retry" otherButtonTitles:@"Cancel", nil];
            //[alert show];
        }
    }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)done {
    // Return any edited content to the host app.
    // This template doesn't do anything, so we just echo the passed in items.
    [self.extensionContext completeRequestReturningItems:self.extensionContext.inputItems completionHandler:nil];
}


-(void)loadData{
    //Create and add a spinner
    UIActivityIndicatorView* spinner = [[UIActivityIndicatorView alloc]initWithFrame:CGRectMake(135,140,50,50)];
    spinner.activityIndicatorViewStyle = UIActivityIndicatorViewStyleGray;
    [self.view addSubview:spinner];
    spinner.hidesWhenStopped = YES;
    [spinner startAnimating];
    
    ListClient* client = [self getClient];
    
    NSURLSessionTask* task = [client getList:@"Research Projects" callback:^(ListEntity *list, NSError *error) {
        
        //If list doesn't exists, create one with name Research Projects
        if(list){
            dispatch_async(dispatch_get_main_queue(), ^{
                [self getProjectsFromList:spinner];
            });
        }else{
            dispatch_async(dispatch_get_main_queue(), ^{
                [self createProjectList:spinner];
            });
        }
        
    }];
    [task resume];
}


-(void)getProjectsFromList:(UIActivityIndicatorView *) spinner{
    ListClient* client = [self getClient];
    
    NSURLSessionTask* listProjectsTask = [client getListItems:@"Research Projects" callback:^(NSMutableArray *listItems, NSError *error) {
        if(!error){
            self.projectsList = listItems;
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.projectTable reloadData];
                [spinner stopAnimating];
            });
        }
    }];
    [listProjectsTask resume];
}


-(void)createProjectList:(UIActivityIndicatorView *) spinner{
    ListClient* client = [self getClient];
    
    ListEntity* newList = [[ListEntity alloc ] init];
    [newList setTitle:@"Research Projects"];
    
    NSURLSessionTask* createProjectListTask = [client createList:newList :^(ListEntity *list, NSError *error) {
        [spinner stopAnimating];
    }];
    [createProjectListTask resume];
}

-(ProjectClientEx*)getClient{
    OAuthentication* authentication = [OAuthentication alloc];
    [authentication setToken:token];
    
    return [[ProjectClientEx alloc] initWithUrl:@"https://foxintergen.sharepoint.com/ContosoResearchTracker"
                               credentials: authentication];
}

- (IBAction)Login:(id)sender {
    [self performLogin:FALSE];
}

- (IBAction)Clear:(id)sender {
    NSError *error;
    LoginClient *client = [[LoginClient alloc] initWithParameters: clientId: redirectUriString:resourceId :authority];
    
    [client clearCredentials: &error];
}



//Table actions
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString* identifier = @"ProjectListCell";
    ProjectTableExtensionViewCell *cell =[tableView dequeueReusableCellWithIdentifier: identifier ];
    
    ListItem *item = [self.projectsList objectAtIndex:indexPath.row];
    cell.ProjectName.text = [item getTitle];
    
    return cell;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.projectsList count];
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
    return 40;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    UIActivityIndicatorView* spinner = [[UIActivityIndicatorView alloc]initWithFrame:CGRectMake(135,140,50,50)];
    spinner.activityIndicatorViewStyle = UIActivityIndicatorViewStyleGray;
    [self.view addSubview:spinner];
    spinner.hidesWhenStopped = YES;
    
    [spinner startAnimating];
    
    currentEntity= [self.projectsList objectAtIndex:indexPath.row];
    
    Reference* newReference = [[Reference alloc] init];
    newReference.title = @"";
    newReference.url = self.urlTxt.text;
    newReference.comments = @"";
    
    __weak ActionViewController *sself = self;
    
    NSURLSessionTask* task =[[self getClient] addReference:@"Research References" item:newReference callback:^(BOOL success, NSError *error) {
        [spinner stopAnimating];
        if(error == nil){
            dispatch_async(dispatch_get_main_queue(), ^{
                sself.projectTable.hidden = true;
                sself.selectProjectLbl.hidden = true;
                sself.successMsg.hidden = false;
                sself.successMsg.text = [NSString stringWithFormat:@"Reference added successfully to the %@ Project.", [currentEntity getTitle]];
            });
        }
    }];
    
    [task resume];
}

@end
